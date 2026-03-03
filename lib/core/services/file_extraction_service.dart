import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../models/sequence.dart';
import '../models/track.dart';
import 'package:command_center_app/core/services/settings_service.dart';
import 'package:flutter/foundation.dart';

class ParsedMetadata {
  final double? bpm;
  final String key;
  final String cleanName;

  ParsedMetadata({this.bpm, required this.key, required this.cleanName});
}

class FileExtractionService {
  static final List<String> _validKeys = [
    'A',
    'Am',
    'A#',
    'A#m',
    'Bb',
    'Bbm',
    'B',
    'Bm',
    'C',
    'Cm',
    'C#',
    'C#m',
    'Db',
    'Dbm',
    'D',
    'Dm',
    'D#',
    'D#m',
    'Eb',
    'Ebm',
    'E',
    'Em',
    'F',
    'Fm',
    'F#',
    'F#m',
    'Gb',
    'Gbm',
    'G',
    'Gm',
    'G#',
    'G#m',
    'Ab',
    'Abm',
  ];

  static ParsedMetadata parseMetadata(String rawName) {
    double? bpm;
    String? key;
    String cleanName = rawName;

    // Extract BPM
    final bpmRegExp = RegExp(r'(\d+(?:\.\d+)?)\s*bpm', caseSensitive: false);
    final bpmMatch = bpmRegExp.firstMatch(rawName);
    if (bpmMatch != null) {
      bpm = double.tryParse(bpmMatch.group(1)!);
      cleanName = cleanName.replaceFirst(bpmMatch.group(0)!, '');
    }

    // Extract Key
    final keyPatterns = [
      RegExp(r'\[([A-G][#b]?m?)\]', caseSensitive: false),
      RegExp(r'\(([A-G][#b]?m?)\)', caseSensitive: false),
      RegExp(r'-\s*([A-G][#b]?m?)(?:\s|$)', caseSensitive: false),
      RegExp(r'_([A-G][#b]?m?)\b', caseSensitive: false),
      RegExp(r'\s([A-G][#b]?m?)$', caseSensitive: false),
    ];

    for (var pattern in keyPatterns) {
      final matches = pattern.allMatches(rawName);
      for (var match in matches) {
        String possibleKeyLower = match.group(1)!.toLowerCase();

        var matchingKey = _validKeys.firstWhere(
          (k) => k.toLowerCase() == possibleKeyLower,
          orElse: () => '',
        );

        if (matchingKey.isNotEmpty) {
          key = matchingKey;
          cleanName = cleanName.replaceFirst(match.group(0)!, '');
          break;
        }
      }
      if (key != null) break;
    }

    // Final string cleanup
    cleanName = cleanName
        .replaceAll(RegExp(r'[^a-zA-Z0-9 \-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    while (cleanName.endsWith('-')) {
      cleanName = cleanName.substring(0, cleanName.length - 1).trim();
    }

    return ParsedMetadata(
      bpm: bpm,
      key: key ?? 'Auto',
      cleanName: cleanName.isEmpty ? 'Untitled Sequence' : cleanName,
    );
  }

  /// Scans the local app directory for existing extracted sequences and reconstructs them into memory on app boot.
  static Future<List<Sequence>> loadSavedSequences() async {
    final Directory docsDir = await SettingsService().getStorageDirectory();
    final String baseDirPath = p.join(
      docsDir.path,
      'CommandCenter',
      'Sequences',
    );
    final Directory baseDir = Directory(baseDirPath);

    if (!await baseDir.exists()) {
      return [];
    }

    List<Sequence> loadedSequences = [];
    bool autoRoute = await SettingsService().getAutoRouteClickCues();
    String clickKeywords = await SettingsService().getClickTrackKeywords();
    String cueKeywords = await SettingsService().getCueTrackKeywords();

    // Read subdirectories (each subdirectory is a Sequence)
    await for (var entity in baseDir.list(recursive: false)) {
      if (entity is Directory) {
        String sequenceName = p.basename(entity.path);
        List<Track> tracks = [];

        await for (var file in entity.list(recursive: false)) {
          if (file is File) {
            final ext = p.extension(file.path).toLowerCase();
            if (ext == '.wav' ||
                ext == '.mp3' ||
                ext == '.ogg' ||
                ext == '.flac') {
              tracks.add(
                Track.fromFileName(
                  file.path,
                  p.basename(file.path),
                  autoRoute: autoRoute,
                  clickKeywords: clickKeywords,
                  cueKeywords: cueKeywords,
                ),
              );
            }
          }
        }

        if (tracks.isNotEmpty) {
          tracks.sort((a, b) {
            if (a.isClickOrCues && !b.isClickOrCues) return -1;
            if (!a.isClickOrCues && b.isClickOrCues) return 1;
            return a.name.compareTo(b.name);
          });
          final metadata = parseMetadata(sequenceName);

          loadedSequences.add(
            Sequence(
              id: sequenceName.toLowerCase().replaceAll(' ', '_'),
              name: metadata.cleanName,
              folderPath: entity.path,
              bpm: metadata.bpm,
              detectedKey: metadata.key,
              tracks: tracks,
            ),
          );
        }
      }
    }

    return loadedSequences;
  }

  /// Prompts the user to pick a ZIP file, then extracts it to the local app directory.
  /// Returns a constructed Sequence object if successful.
  static Future<Sequence?> pickAndExtractSequence() async {
    // 1. Pick a zip file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'zip',
        'rar',
      ], // archive pkg supports zip natively, we can handle rar later if needed.
    );

    if (result == null || result.files.single.path == null) {
      // User canceled the picker
      return null;
    }

    String sourceFilePath = result.files.single.path!;
    String sequenceName = p.basenameWithoutExtension(sourceFilePath);

    // Clean name a bit
    sequenceName = sequenceName
        .replaceAll(RegExp(r'[^a-zA-Z0-9 \-]'), ' ')
        .trim();

    // 2. Determine target directory
    final Directory docsDir = await SettingsService().getStorageDirectory();
    final bool autoRoute = await SettingsService().getAutoRouteClickCues();
    final String clickKeywords = await SettingsService()
        .getClickTrackKeywords();
    final String cueKeywords = await SettingsService().getCueTrackKeywords();
    final String targetDirPath = p.join(
      docsDir.path,
      'CommandCenter',
      'Sequences',
      sequenceName,
    );
    final Directory targetDir = Directory(targetDirPath);

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // 3. Extract the ZIP
    // Using file bytes directly for archive ^4.0 compatibility

    try {
      final bytes = await File(sourceFilePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      List<Track> extractedTracks = [];
      List<String> seenExtensions = [];
      List<String> seenFileNames = [];

      for (var file in archive.files) {
        if (file.isFile) {
          // Ignore macOS metadata and hidden files
          if (file.name.contains('__MACOSX') || file.name.startsWith('.')) {
            continue;
          }

          // Only process audio files (basic check)
          final ext = p.extension(file.name).toLowerCase();
          seenExtensions.add(ext);
          seenFileNames.add(file.name);
          debugPrint(
            'Found file in ZIP: ${file.name} (Ext: $ext)',
          ); // Debug logging

          if (ext == '.wav' ||
              ext == '.mp3' ||
              ext == '.ogg' ||
              ext == '.flac') {
            final String outputFileName = p.basename(file.name);

            // Ignore macOS hidden files that are not caught by the startswith check if they have a path
            if (outputFileName.startsWith('.')) continue;

            final String outputFilePath = p.join(targetDirPath, outputFileName);

            try {
              final outputStream = OutputFileStream(outputFilePath);
              file.writeContent(outputStream);
              outputStream.close();

              // Generate Track Object
              extractedTracks.add(
                Track.fromFileName(
                  outputFilePath,
                  outputFileName,
                  autoRoute: autoRoute,
                  clickKeywords: clickKeywords,
                  cueKeywords: cueKeywords,
                ),
              );
              debugPrint('Successfully extracted: $outputFileName');
            } catch (e) {
              debugPrint('Failed to write stream for $outputFileName: $e');
            }
          }
        }
      }

      // File extraction complete.

      if (extractedTracks.isEmpty) {
        // Clean up empty directory if no audio files were found
        await targetDir.delete(recursive: true);
        String extSet = seenExtensions.toSet().join(', ');
        String fileList = seenFileNames.take(5).join(', ');
        throw Exception(
          'Extraction summary -> Bytes Read: ${bytes.length}, Archive Files Total: ${archive.files.length}, Valid Audio Files Found: 0. Inside ZIP: [$fileList...]. Extensions found: [$extSet]. Supported formats are WAV, MP3, OGG, FLAC.',
        );
      }

      // Optional: Sort tracks (Click first, then cues, then alphabetical)
      extractedTracks.sort((a, b) {
        if (a.isClickOrCues && !b.isClickOrCues) return -1;
        if (!a.isClickOrCues && b.isClickOrCues) return 1;
        return a.name.compareTo(b.name);
      });

      // 4. Return new Sequence entity
      final metadata = parseMetadata(sequenceName);

      return Sequence(
        id: sequenceName.toLowerCase().replaceAll(' ', '_'),
        name: metadata.cleanName,
        folderPath: targetDirPath,
        bpm: metadata.bpm,
        detectedKey: metadata.key,
        tracks: extractedTracks,
      );
    } catch (e) {
      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
      throw Exception(
        'Failed to process sequence file. The file may be corrupted, empty, or not a valid ZIP archive. Details: $e',
      );
    }
  }

  /// Renames the actual source directory for a sequence in the library. Returns the updated Sequence.
  static Future<Sequence> renameSequenceFolder(
    Sequence sequence,
    String newName,
  ) async {
    final Directory oldDir = Directory(sequence.folderPath);
    if (!await oldDir.exists())
      throw Exception('Sequence folder does not exist');

    // Clean name
    final safeName = newName.replaceAll(RegExp(r'[^a-zA-Z0-9 \-]'), ' ').trim();
    if (safeName.isEmpty) throw Exception('Invalid sequence name');

    final String targetDirPath = p.join(oldDir.parent.path, safeName);
    final Directory newDir = Directory(targetDirPath);

    if (await newDir.exists() && oldDir.path != newDir.path) {
      throw Exception(
        'A sequence with that name already exists in the library',
      );
    }

    if (oldDir.path != newDir.path) {
      await oldDir.rename(targetDirPath);
    }

    List<Track> updatedTracks = sequence.tracks.map<Track>((t) {
      String newFilePath = p.join(targetDirPath, p.basename(t.filePath));
      // Using existing model values to prevent loss of data if we implement metadata later
      return Track(
        id: t.id,
        name: t.name,
        filePath: newFilePath,
        isClickOrCues: t.isClickOrCues,
        volume: t.volume,
        pan: t.pan,
        mute: t.mute,
        solo: t.solo,
      );
    }).toList();

    return Sequence(
      id: safeName.toLowerCase().replaceAll(' ', '_'),
      name: safeName,
      folderPath: targetDirPath,
      tracks: updatedTracks,
      cueTags: sequence.cueTags,
      detectedKey: sequence.detectedKey,
      pauseAfterSeconds: sequence.pauseAfterSeconds,
      pitchOverride: sequence.pitchOverride,
    );
  }

  /// Permanently deletes a sequence folder from the local disk.
  static Future<void> deleteSequenceFolder(Sequence sequence) async {
    final Directory dir = Directory(sequence.folderPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
