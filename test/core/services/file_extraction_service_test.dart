import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:command_center_app/core/services/file_extraction_service.dart';
import 'package:command_center_app/core/services/settings_service.dart';
import 'package:command_center_app/core/models/sequence.dart';
import 'package:command_center_app/core/models/track.dart';

void main() {
  group('FileExtractionService - parseMetadata', () {
    test('extracts BPM correctly', () {
      final meta = FileExtractionService.parseMetadata('My Song 120bpm');
      expect(meta.bpm, 120.0);
      expect(meta.cleanName, 'My Song');
      expect(meta.key, 'Auto');
    });

    test('extracts decimal BPM correctly', () {
      final meta = FileExtractionService.parseMetadata('Track 124.5 BPM');
      expect(meta.bpm, 124.5);
      expect(meta.cleanName, 'Track');
      expect(meta.key, 'Auto');
    });

    test('extracts Key correctly from brackets', () {
      final meta = FileExtractionService.parseMetadata('Song Name [Am]');
      expect(meta.bpm, isNull);
      expect(meta.key, 'Am');
      expect(meta.cleanName, 'Song Name');
    });

    test('extracts Key correctly from parenthesis', () {
      final meta = FileExtractionService.parseMetadata('Test Song (C#m)');
      expect(meta.key, 'C#m');
      expect(meta.cleanName, 'Test Song');
    });

    test('extracts Key correctly following dash', () {
      final meta = FileExtractionService.parseMetadata('Rock Anthem - G');
      expect(meta.key, 'G');
      expect(meta.cleanName, 'Rock Anthem');
    });

    test('extracts both BPM and Key simultaneously', () {
      final meta = FileExtractionService.parseMetadata('Pop Hit 128bpm [F#]');
      expect(meta.bpm, 128.0);
      expect(meta.key, 'F#');
      expect(meta.cleanName, 'Pop Hit');
    });

    test('ignores invalid keys', () {
      final meta = FileExtractionService.parseMetadata(
        'Some Track (H#m) 100bpm',
      );
      expect(meta.bpm, 100.0);
      expect(meta.key, 'Auto');
      expect(meta.cleanName, 'Some Track H m');
    });

    test('handles empty or pure symbol sequences gracefully', () {
      final meta = FileExtractionService.parseMetadata('--- ***');
      expect(meta.cleanName, 'Untitled Sequence');
    });
  });

  group('FileExtractionService - File System Manipulations', () {
    late Directory tempStorageDir;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempStorageDir = Directory.systemTemp.createTempSync(
        'command_center_test_extractions',
      );

      SharedPreferences.setMockInitialValues({
        'custom_storage_path': tempStorageDir.path,
      });

      final service = SettingsService();
      await service.init();
    });

    tearDown(() {
      if (tempStorageDir.existsSync()) {
        tempStorageDir.deleteSync(recursive: true);
      }
    });

    test('saveSequenceConfig writes sequence.json to folder', () async {
      final seqDir = Directory(p.join(tempStorageDir.path, 'My_Song'));
      seqDir.createSync(recursive: true);

      final sequence = Sequence(
        id: 's1',
        name: 'My Song',
        folderPath: seqDir.path,
        tracks: [Track(id: 't1', name: 'Click', filePath: '/dummy/click.wav')],
      );

      await FileExtractionService.saveSequenceConfig(sequence);

      final expectedFile = File(p.join(seqDir.path, '.sequence_config.json'));
      expect(expectedFile.existsSync(), isTrue);

      final contents = expectedFile.readAsStringSync();
      expect(contents.contains('"id":"s1"'), isTrue);
      expect(contents.contains('"name":"My Song"'), isTrue);
    });

    test(
      'deleteSequenceFolder completely removes everything recursively',
      () async {
        final targetDir = Directory(p.join(tempStorageDir.path, 'Delete_Me'));
        targetDir.createSync(recursive: true);
        File(p.join(targetDir.path, 'click.wav')).createSync();

        final sequence = Sequence(
          id: 'del1',
          name: 'Delete Me',
          folderPath: targetDir.path,
          tracks: [],
        );

        expect(targetDir.existsSync(), isTrue);
        await FileExtractionService.deleteSequenceFolder(sequence);
        expect(targetDir.existsSync(), isFalse);
      },
    );

    test(
      'renameSequenceFolder actually renames path and tracks correctly',
      () async {
        final origDir = Directory(p.join(tempStorageDir.path, 'Original'));
        origDir.createSync(recursive: true);
        File(p.join(origDir.path, 'click.wav')).createSync();

        final sequence = Sequence(
          id: 'orig',
          name: 'Original',
          folderPath: origDir.path,
          tracks: [
            Track(
              id: 't1',
              name: 'Click',
              filePath: p.join(origDir.path, 'click.wav'),
            ),
          ],
        );

        final updatedSeq = await FileExtractionService.renameSequenceFolder(
          sequence,
          'Renamed Song',
        );

        expect(updatedSeq.name, 'Renamed Song');
        expect(
          updatedSeq.folderPath,
          p.join(tempStorageDir.path, 'Renamed Song'),
        );
        expect(
          updatedSeq.tracks.first.filePath,
          p.join(tempStorageDir.path, 'Renamed Song', 'click.wav'),
        );

        // Check physical file system
        final newDir = Directory(p.join(tempStorageDir.path, 'Renamed Song'));
        expect(newDir.existsSync(), isTrue);
        expect(File(p.join(newDir.path, 'click.wav')).existsSync(), isTrue);

        expect(origDir.existsSync(), isFalse);
      },
    );

    test(
      'loadSavedSequences reads tracks correctly from structured directories',
      () async {
        final baseDirPath = p.join(
          tempStorageDir.path,
          'CommandCenter',
          'Sequences',
        );
        final seqDir = Directory(p.join(baseDirPath, 'Cool Song [Am] 130bpm'));
        seqDir.createSync(recursive: true);

        File(p.join(seqDir.path, 'click.wav')).createSync();
        File(p.join(seqDir.path, 'drums.wav')).createSync();

        // Extraneous file to test filtering
        File(p.join(seqDir.path, 'readme.txt')).createSync();

        final sequences = await FileExtractionService.loadSavedSequences();

        expect(sequences, isNotEmpty);
        expect(sequences.length, 1);

        final loaded = sequences.first;
        expect(loaded.name, 'Cool Song');
        expect(loaded.detectedKey, 'Am');
        expect(loaded.bpm, 130.0);
        expect(loaded.tracks.length, 2); // Should only load the two .wav files

        // Verification of Click finding logic and path mappings
        expect(
          loaded.tracks.first.isClickOrCues,
          isTrue,
        ); // 'click' keyword places it first automatically!
        expect(loaded.tracks.last.name, 'drums');
        expect(loaded.tracks.last.isClickOrCues, isFalse);
      },
    );
  });
}
