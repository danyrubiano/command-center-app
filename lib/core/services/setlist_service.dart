import 'dart:convert';
import 'dart:io';

import 'package:command_center_app/core/models/setlist.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class SetlistService {
  static Future<Directory> _getSetlistDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final setlistsDir = Directory(p.join(docsDir.path, 'CommandCenter', 'Setlists'));
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
      print('Failed to load setlists: $e');
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
      print('Failed to save setlist: $e');
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
      print('Failed to delete setlist: $e');
      throw Exception('Failed to delete setlist: $e');
    }
  }

  /// Scans all saved setlists. If a setlist contains a sequence with [oldFolderPath],
  /// its name, id, folderPath, and tracks are updated to match [updatedSequence].
  static Future<void> updateSequenceReferencesGlobal(String oldFolderPath, Sequence updatedSequence) async {
    try {
      final list = await getSavedSetlists();
      for (Setlist sl in list) {
        bool changed = false;
        
        for (int i = 0; i < sl.sequences.length; i++) {
           if (sl.sequences[i].folderPath == oldFolderPath) {
              // Create a clone but retain the setlist's unique runtime ID for reordering
              final originalId = sl.sequences[i].id; 
              
              sl.sequences[i] = Sequence.fromJson(updatedSequence.toJson());
              sl.sequences[i].id = originalId; // keep the unique builder ID!
              
              changed = true;
           }
        }

        if (changed) {
           await saveSetlist(sl);
        }
      }
    } catch (e) {
      print('Failed to update Sequence references globally: $e');
    }
  }

  static Future<void> saveLastPlayedSetlistId(String id) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(docsDir.path, 'CommandCenter', 'last_played_setlist.txt'));
      await file.writeAsString(id);
    } catch (e) {
      print('Failed to save last played setlist id: $e');
    }
  }

  static Future<String?> getLastPlayedSetlistId() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(docsDir.path, 'CommandCenter', 'last_played_setlist.txt'));
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      print('Failed to get last played setlist id: $e');
    }
    return null;
  }
}
