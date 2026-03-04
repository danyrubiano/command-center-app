import 'dart:convert';
import 'dart:io';

import 'package:command_center_app/core/models/setlist.dart';
import 'package:command_center_app/core/models/sequence.dart';
import 'package:command_center_app/core/services/settings_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class SetlistService {
  static Future<Directory> _getSetlistDir() async {
    final docsDir = await SettingsService().getStorageDirectory();
    final setlistsDir = Directory(
      p.join(docsDir.path, 'CommandCenter', 'Setlists'),
    );
    if (!await setlistsDir.exists()) {
      await setlistsDir.create(recursive: true);
    }
    return setlistsDir;
  }

  static Future<List<Setlist>> getSavedSetlists() async {
    try {
      final dir = await _getSetlistDir();
      final List<Setlist> list = [];
      await for (var entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          final content = await entity.readAsString();
          final jsonMap = jsonDecode(content);
          list.add(Setlist.fromJson(jsonMap));
        }
      }
      return list;
    } catch (e) {
      debugPrint('Failed to load setlists: $e');
      return [];
    }
  }

  static Future<void> saveSetlist(Setlist setlist) async {
    try {
      final dir = await _getSetlistDir();
      final file = File(p.join(dir.path, '${setlist.id}.json'));
      final jsonString = jsonEncode(setlist.toJson());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Failed to save setlist: $e');
      throw Exception('Failed to save setlist: $e');
    }
  }

  static Future<void> deleteSetlist(String id) async {
    try {
      final dir = await _getSetlistDir();
      final file = File(p.join(dir.path, '$id.json'));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete setlist: $e');
      throw Exception('Failed to delete setlist: $e');
    }
  }

  /// Scans all saved setlists. If a setlist contains a sequence with [oldFolderPath],
  /// its name, id, folderPath, and tracks are updated to match [updatedSequence].
  static Future<void> updateSequenceReferencesGlobal(
    String oldFolderPath,
    Sequence updatedSequence,
  ) async {
    try {
      final list = await getSavedSetlists();
      for (Setlist sl in list) {
        bool changed = false;

        for (int i = 0; i < sl.sequences.length; i++) {
          if (sl.sequences[i].folderPath == oldFolderPath) {
            // Create a clone but retain the setlist's unique runtime ID for reordering
            final originalId = sl.sequences[i].id;

            final updatedJson = updatedSequence.toJson();
            updatedJson['id'] = originalId;

            sl.sequences[i] = Sequence.fromJson(updatedJson);

            changed = true;
          }
        }

        if (changed) {
          await saveSetlist(sl);
        }
      }
    } catch (e) {
      debugPrint('Failed to update Sequence references globally: $e');
    }
  }

  /// Scans all saved setlists and physically removes any sequence matching the [folderPath].
  /// This ensures that deleted sequences don't show up orphaned on the Player screen.
  static Future<void> removeSequenceReferencesGlobal(String folderPath) async {
    try {
      final list = await getSavedSetlists();
      for (Setlist sl in list) {
        bool changed = false;

        // Removing items backwards to cleanly avoid shifting indices
        for (int i = sl.sequences.length - 1; i >= 0; i--) {
          if (sl.sequences[i].folderPath == folderPath) {
            sl.sequences.removeAt(i);
            changed = true;
          }
        }

        if (changed) {
          await saveSetlist(sl);
        }
      }
    } catch (e) {
      debugPrint('Failed to remove Sequence references globally: $e');
    }
  }

  static Future<void> saveLastPlayedSetlistId(String id) async {
    try {
      final docsDir = await SettingsService().getStorageDirectory();
      final file = File(
        p.join(docsDir.path, 'CommandCenter', 'last_played_setlist.txt'),
      );
      await file.writeAsString(id);
    } catch (e) {
      debugPrint('Failed to save last played setlist id: $e');
    }
  }

  static Future<String?> getLastPlayedSetlistId() async {
    try {
      final docsDir = await SettingsService().getStorageDirectory();
      final file = File(
        p.join(docsDir.path, 'CommandCenter', 'last_played_setlist.txt'),
      );
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      debugPrint('Failed to get last played setlist id: $e');
    }
    return null;
  }
}
