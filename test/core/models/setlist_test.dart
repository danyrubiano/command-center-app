import 'package:flutter_test/flutter_test.dart';
import 'package:command_center_app/core/models/setlist.dart';
import 'package:command_center_app/core/models/sequence.dart';
import 'package:command_center_app/core/models/track.dart';

void main() {
  group('Setlist Model Tests', () {
    test('Setlist instantiation with minimal parameters', () {
      final setlist = Setlist(id: 'setlist123', name: 'My Setlist');

      expect(setlist.id, 'setlist123');
      expect(setlist.name, 'My Setlist');
      expect(setlist.sequences, isEmpty);
      expect(setlist.isUnsaved, isFalse);
    });

    test('Setlist instantiation with explicit parameters', () {
      final sequence = Sequence(
        id: 'seq1',
        name: 'Seq 1',
        folderPath: '/path/to/seq1',
        tracks: [],
      );
      final setlist = Setlist(
        id: 'setlist_full',
        name: 'Full Setlist',
        sequences: [sequence],
        isUnsaved: true,
      );

      expect(setlist.id, 'setlist_full');
      expect(setlist.name, 'Full Setlist');
      expect(setlist.sequences.length, 1);
      expect(setlist.sequences.first.id, 'seq1');
      expect(setlist.isUnsaved, isTrue);
    });

    test('Setlist toJson output', () {
      final track = Track(
        id: 't1',
        name: 'Click',
        filePath: '/path/to/click.wav',
        isClickOrCues: true,
      );
      final sequence = Sequence(
        id: 'seq1',
        name: 'Seq 1',
        folderPath: '/path/to/seq1',
        tracks: [track],
      );

      final setlist = Setlist(
        id: 'setlist_json',
        name: 'JSON Setlist',
        sequences: [sequence],
        isUnsaved:
            true, // Should not matter for serialization based on standard implementation
      );

      final json = setlist.toJson();

      expect(json['id'], 'setlist_json');
      expect(json['name'], 'JSON Setlist');
      expect(json['sequences'], isA<List>());
      expect((json['sequences'] as List).length, 1);

      // runtime flag generally doesn't serialize but let's just make sure the rest is intact
      expect((json['sequences'] as List).first['id'], 'seq1');
    });

    test('Setlist fromJson construction', () {
      final json = {
        'id': 'from_json_id',
        'name': 'Parsed Setlist',
        'sequences': [
          {
            'id': 'seq_parsed',
            'name': 'Parsed Seq',
            'folderPath': '/path/to/parsed_seq',
            'detectedKey': 'Auto',
            'pitchOverride': 0,
            'bpm': 120.0,
            'pauseAfterSeconds': 0,
            'transitionAction': 'stop',
            'cueTags': [],
            'tracks': [
              {
                'id': 't2',
                'name': 'Drums',
                'filePath': '/path/to/drums.wav',
                'volume': 1.0,
                'mute': false,
                'solo': false,
                'isClickOrCues': false,
              },
            ],
          },
        ],
      };

      final setlist = Setlist.fromJson(json);

      expect(setlist.id, 'from_json_id');
      expect(setlist.name, 'Parsed Setlist');
      expect(setlist.sequences.length, 1);
      expect(setlist.sequences.first.name, 'Parsed Seq');
      expect(setlist.sequences.first.tracks.length, 1);
      expect(setlist.sequences.first.tracks.first.name, 'Drums');
      expect(setlist.isUnsaved, isFalse); // Default
    });

    test('Setlist fromJson with missing sequences handles null gracefully', () {
      final json = {
        'id': 'from_json_missing_seq',
        'name': 'Missing Sequences Setlist',
      };

      final setlist = Setlist.fromJson(json);
      expect(setlist.id, 'from_json_missing_seq');
      expect(setlist.name, 'Missing Sequences Setlist');
      expect(setlist.sequences, isEmpty);
    });
  });
}
