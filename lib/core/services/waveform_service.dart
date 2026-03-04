import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:command_center_app/core/models/sequence.dart';
import 'package:command_center_app/core/models/track.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:path/path.dart' as p;

class WaveformService {
  /// Extracts waveforms for all non-click/cue tracks in a sequence, merges them,
  /// and returns the merged Waveform.
  static Future<Waveform> getMergedWaveform(
    Sequence sequence, {
    void Function(double progress)? onProgress,
  }) async {
    final musicTracks = sequence.tracks.where((t) => !t.isClickOrCues).toList();
    if (musicTracks.isEmpty) {
      throw Exception('No music tracks found to generate waveform.');
    }

    final sequenceDir = p.dirname(musicTracks.first.filePath);
    final mergedWaveFile = File(p.join(sequenceDir, 'merged_waveform.wave'));

    // If we already have the merged waveform cached, assume we have the stems too
    if (mergedWaveFile.existsSync()) {
      onProgress?.call(1.0);
      return await JustWaveform.parse(mergedWaveFile);
    }

    List<Waveform> extractedMusicWaveforms = [];

    // Extract individual waveforms (including click and cues so they have VU meters)
    for (int i = 0; i < sequence.tracks.length; i++) {
      final track = sequence.tracks[i];
      final trackFile = File(track.filePath);
      final waveFile = File(p.join(sequenceDir, '${track.name}.wave'));

      if (!waveFile.existsSync()) {
        final completer = Completer<Waveform>();

        final stream = JustWaveform.extract(
          audioInFile: trackFile,
          waveOutFile: waveFile,
          zoom: const WaveformZoom.pixelsPerSecond(50),
        );

        stream.listen(
          (progress) {
            double currentProgress = progress.progress;
            // Weighted progress based on total tracks to extract + 1 for merge
            double overallProgress =
                (i + currentProgress) / (sequence.tracks.length + 1);
            onProgress?.call(overallProgress);

            if (progress.waveform != null) {
              if (!completer.isCompleted) {
                completer.complete(progress.waveform);
              }
            }
          },
          onError: (e) {
            if (!completer.isCompleted) completer.completeError(e);
          },
        );

        final wave = await completer.future;
        if (!track.isClickOrCues) extractedMusicWaveforms.add(wave);
      } else {
        final parsed = await JustWaveform.parse(waveFile);
        if (!track.isClickOrCues) extractedMusicWaveforms.add(parsed);
      }
    }

    onProgress?.call((sequence.tracks.length) / (sequence.tracks.length + 1));

    // Merge only the music waveforms into a single waveform
    final merged = _mergeWaveforms(extractedMusicWaveforms);

    // Save the merged waveform header/data so we can parse it from disk next time.
    final bytes = BytesBuilder();
    // Reconstruct the audiowaveform header (20 bytes)
    final topWave = extractedMusicWaveforms.first;
    final headerList = Uint32List(5);
    headerList[0] = topWave.version;
    headerList[1] = 0; // flags (0 = 16 bit)
    headerList[2] = topWave.sampleRate;
    headerList[3] = topWave.samplesPerPixel;
    headerList[4] = merged.length;

    bytes.add(headerList.buffer.asUint8List());
    bytes.add((merged.data as Int16List).buffer.asUint8List());

    await mergedWaveFile.writeAsBytes(bytes.toBytes());

    onProgress?.call(1.0);
    return merged;
  }

  static Waveform _mergeWaveforms(List<Waveform> waveforms) {
    if (waveforms.isEmpty) throw Exception("No waveforms to merge");
    if (waveforms.length == 1) return waveforms.first;

    // Find the longest waveform array
    int maxLength = 0;
    for (var w in waveforms) {
      if (w.data.length > maxLength) maxLength = w.data.length;
    }

    final mergedData = Int16List(maxLength);

    for (int i = 0; i < maxLength; i++) {
      int sum = 0;
      int count = 0;

      for (var w in waveforms) {
        if (i < w.data.length) {
          sum += w.data[i];
          count++;
        }
      }

      if (count > 0) {
        // Average the amplitudes so it doesn't clip excessively
        mergedData[i] = (sum / count).round();
      }
    }

    final topWave = waveforms.first;
    return Waveform(
      version: topWave.version,
      flags: 0, // 16 bit
      sampleRate: topWave.sampleRate,
      samplesPerPixel: topWave.samplesPerPixel,
      length:
          maxLength ~/
          2, // length is the number of pixels, data array is 2x length (min, max per pixel)
      data: mergedData,
    );
  }

  static Future<Map<String, Waveform>> getTrackWaveforms(
    Sequence sequence,
  ) async {
    Map<String, Waveform> map = {};
    for (var t in sequence.tracks) {
      final sequenceDir = p.dirname(t.filePath);
      final waveFile = File(p.join(sequenceDir, '${t.name}.wave'));
      if (waveFile.existsSync()) {
        map[t.id] = await JustWaveform.parse(waveFile);
      }
    }
    return map;
  }

  /// Automatically parses the Cues track waveform, sweeps for spoken voice peaks,
  /// groups them into functional vocal blocks, and spits out isolated CueTag sequences
  /// timed to the moment the speaker finishes announcing the section!
  static Future<List<CueTag>> autoDetectCues(Sequence sequence) async {
    // Locate the Guia / Cues track
    Track? cuesTrack;
    for (var t in sequence.tracks) {
      if (t.isClickOrCues) {
        String lower = t.name.toLowerCase();
        if (lower.contains('cue') ||
            lower.contains('gui') ||
            lower.contains('vocal') ||
            lower.contains('voz')) {
          cuesTrack = t;
          break;
        }
      }
    }

    // Fallback: pick any system track that isn't clearly just the Click/Metronome
    if (cuesTrack == null) {
      for (var t in sequence.tracks) {
        if (t.isClickOrCues &&
            !t.name.toLowerCase().contains('click') &&
            !t.name.toLowerCase().contains('clic') &&
            !t.name.toLowerCase().contains('clk')) {
          cuesTrack = t;
          break;
        }
      }
    }

    if (cuesTrack == null) return [];

    final sequenceDir = p.dirname(cuesTrack.filePath);
    final waveFile = File(p.join(sequenceDir, '${cuesTrack.name}.wave'));

    // If the waveform hasn't been cached, we can't do fast analysis
    if (!waveFile.existsSync()) return [];

    final waveform = await JustWaveform.parse(waveFile);

    List<CueTag> detectedTags = [];
    int threshold =
        1500; // Peak 16-bit threshold to consider "Voice Transient" Active
    bool inCue = false;
    double silenceDuration = 0;

    // Waveform Zoom is typically 50 pixels per second, but we verify here.
    int pixelsPerSecond = (waveform.sampleRate / waveform.samplesPerPixel)
        .round();
    if (pixelsPerSecond <= 0) pixelsPerSecond = 50;

    for (int i = 0; i < waveform.length; i++) {
      int min = waveform.data[i * 2];
      int max = waveform.data[i * 2 + 1];
      int amplitude = (max - min).abs();

      if (amplitude > threshold) {
        if (!inCue) {
          // Voice burst detected!
          inCue = true;
        }
        // Reset silent counter
        silenceDuration = 0;
      } else {
        if (inCue) {
          silenceDuration += 1.0 / pixelsPerSecond;
          // If it goes quiet for 2.0 full seconds, we assume the Voice Cue is completed
          if (silenceDuration > 2.0) {
            inCue = false;

            // The end of the block is effectively the pixel we went silent
            // We step backwards exactly the 2.0 seconds of silence to map the timestamp.
            int exactEndPixel = i - (2.0 * pixelsPerSecond).toInt();
            if (exactEndPixel < 0) exactEndPixel = 0;

            Duration pos = Duration(
              milliseconds: ((exactEndPixel * 1000) / pixelsPerSecond).round(),
            );

            detectedTags.add(
              CueTag(name: 'Section ${detectedTags.length + 1}', position: pos),
            );
          }
        }
      }
    }

    return detectedTags;
  }
}
