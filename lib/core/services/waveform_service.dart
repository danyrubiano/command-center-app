import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:command_center_app/core/models/sequence.dart';
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
}
