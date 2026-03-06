import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:command_center_app/core/models/setlist.dart';
import 'package:command_center_app/core/models/sequence.dart';
import 'package:command_center_app/core/services/settings_service.dart';
import 'package:command_center_app/core/services/setlist_service.dart';

void main() {
  late Directory tempStorageDir;

  setUp(() async {
    // Create a physical temporary directory for file operations
    tempStorageDir = Directory.systemTemp.createTempSync(
      'command_center_test_setlists',
    );

    // Mock SharedPreferences to point SettingsService to our temp folder perfectly
    SharedPreferences.setMockInitialValues({
      'custom_storage_path': tempStorageDir.path,
    });

    // Force settings service to re-init
    final service = SettingsService();
    await service.init();

    // Just verifying it actually grabs the custom path we mocked
    expect((await service.getStorageDirectory()).path, tempStorageDir.path);
  });

  tearDown(() {
    // Cleanup physical files
    if (tempStorageDir.existsSync()) {
      tempStorageDir.deleteSync(recursive: true);
    }
  });

  group('SetlistService Tests', () {
    test('getSavedSetlists returns empty list when no files exist', () async {
      final list = await SetlistService.getSavedSetlists();
      expect(list, isEmpty);
    });

    test(
      'saveSetlist saves a setlist to disk and getSavedSetlists retrieves it',
      () async {
        final setlist = Setlist(
          id: '123_save_test',
          name: 'Test Save',
          sequences: [],
        );

        // Save
        await SetlistService.saveSetlist(setlist);

        // Retrieve
        final lists = await SetlistService.getSavedSetlists();

        expect(lists.length, 1);
        expect(lists.first.id, '123_save_test');
        expect(lists.first.name, 'Test Save');
      },
    );

    test('deleteSetlist successfully removes file from disk', () async {
      final setlist1 = Setlist(
        id: 'delete_test_1',
        name: 'Delete Me',
        sequences: [],
      );
      final setlist2 = Setlist(
        id: 'delete_test_2',
        name: 'Keep Me',
        sequences: [],
      );

      await SetlistService.saveSetlist(setlist1);
      await SetlistService.saveSetlist(setlist2);

      var lists = await SetlistService.getSavedSetlists();
      expect(lists.length, 2);

      // Delete 1
      await SetlistService.deleteSetlist('delete_test_1');

      lists = await SetlistService.getSavedSetlists();
      expect(lists.length, 1);
      expect(lists.first.id, 'delete_test_2');
    });

    test(
      'updateSequenceReferencesGlobal updates a sequence reference inside multiple setlists',
      () async {
        // Mock Setlists holding an old sequence reference
        final setlist1 = Setlist(
          id: 'sl1',
          name: 'Setlist 1',
          sequences: [
            Sequence(
              id: 'seqRef1',
              name: 'Old Song',
              folderPath: '/old/path/song',
              tracks: [],
            ),
          ],
        );
        final setlist2 = Setlist(
          id: 'sl2',
          name: 'Setlist 2',
          sequences: [
            Sequence(
              id: 'seqRef2',
              name: 'Old Song',
              folderPath: '/old/path/song',
              tracks: [],
            ),
          ],
        );

        await SetlistService.saveSetlist(setlist1);
        await SetlistService.saveSetlist(setlist2);

        // The updated template coming from Library
        final updatedSequence = Sequence(
          id: 'globalId',
          name: 'New Renamed Song',
          folderPath: '/new/path/song',
          tracks: [],
        );

        // Call global updater passing the old folder path as identifier
        await SetlistService.updateSequenceReferencesGlobal(
          '/old/path/song',
          updatedSequence,
        );

        // Verify changes
        final lists = await SetlistService.getSavedSetlists();
        lists.sort(
          (a, b) => a.id.compareTo(b.id),
        ); // Ensure stable validation order

        expect(lists[0].sequences.first.name, 'New Renamed Song');
        expect(lists[0].sequences.first.folderPath, '/new/path/song');
        // Crucially, it must preserve its context-specific unique ID in the setlist!
        expect(lists[0].sequences.first.id, 'seqRef1');

        expect(lists[1].sequences.first.name, 'New Renamed Song');
        expect(lists[1].sequences.first.folderPath, '/new/path/song');
        expect(lists[1].sequences.first.id, 'seqRef2');
      },
    );

    test(
      'removeSequenceReferencesGlobal strips explicit sequences from all folders',
      () async {
        final setlist1 = Setlist(
          id: 'sl1',
          name: 'Setlist 1',
          sequences: [
            Sequence(
              id: 'seq1',
              name: 'Keep Song',
              folderPath: '/path/keep',
              tracks: [],
            ),
            Sequence(
              id: 'seq2',
              name: 'Delete Song',
              folderPath: '/path/delete_me',
              tracks: [],
            ),
          ],
        );

        await SetlistService.saveSetlist(setlist1);

        await SetlistService.removeSequenceReferencesGlobal('/path/delete_me');

        final lists = await SetlistService.getSavedSetlists();
        expect(lists.length, 1);
        expect(lists.first.sequences.length, 1);
        expect(lists.first.sequences.first.id, 'seq1');
        expect(lists.first.sequences.first.name, 'Keep Song');
      },
    );

    test(
      'saveLastPlayedSetlistId and getLastPlayedSetlistId saves effectively to SharedPreferences',
      () async {
        await SetlistService.saveLastPlayedSetlistId('some_cool_id');
        final id = await SetlistService.getLastPlayedSetlistId();
        expect(id, 'some_cool_id');
      },
    );
  });
}
