import 'package:flutter_test/flutter_test.dart';
import 'package:command_center_app/core/models/sequence.dart';
import 'package:command_center_app/core/models/track.dart';

void main() {
  group('Sequence Model', () {
    test('Sequence initializes with default values', () {
      final sequence = Sequence(
        id: 'seq1',
        name: 'My Sequence',
        folderPath: '/path/to/seq1',
        tracks: [],
      );

      expect(sequence.id, 'seq1');
      expect(sequence.name, 'My Sequence');
      expect(sequence.folderPath, '/path/to/seq1');
      expect(sequence.detectedKey, 'Auto');
      expect(sequence.pitchOverride, 0);
      expect(sequence.bpm, isNull);
      expect(sequence.pauseAfterSeconds, 0);
      expect(sequence.transitionAction, TransitionAction.stop);
      expect(sequence.cueTags, isEmpty);
      expect(sequence.tracks, isEmpty);
    });

    test('toJson and fromJson handle CueTags correctly', () {
      final cueTag = CueTag(name: 'Chorus', position: Duration(seconds: 45));

      final sequence = Sequence(
        id: 'seq2',
        name: 'Another Sequence',
        folderPath: '/path/to/seq2',
        cueTags: [cueTag],
        tracks: [],
      );

      final jsonMap = sequence.toJson();
      final decodedSeq = Sequence.fromJson(jsonMap);

      expect(decodedSeq.id, sequence.id);
      expect(decodedSeq.cueTags.length, 1);
      expect(decodedSeq.cueTags.first.name, 'Chorus');
      expect(decodedSeq.cueTags.first.position.inSeconds, 45);
    });

    test('toJson and fromJson serialize fully mapped sequences', () {
      final track = Track(id: 't1', name: 'Guitar', filePath: '/p/g.wav');

      final seq = Sequence(
        id: 'song1',
        name: 'Song 1',
        folderPath: '/p/',
        detectedKey: 'G',
        pitchOverride: 2,
        bpm: 120.0,
        pauseAfterSeconds: 10,
        tracks: [track],
      );

      final decoded = Sequence.fromJson(seq.toJson());

      expect(decoded.name, 'Song 1');
      expect(decoded.detectedKey, 'G');
      expect(decoded.pitchOverride, 2);
      expect(decoded.bpm, 120.0);
      expect(decoded.pauseAfterSeconds, 10);
      expect(decoded.transitionAction, TransitionAction.stop);
      expect(decoded.tracks.length, 1);
      expect(decoded.tracks.first.id, 't1');
    });
  });

  group('CueTag Model', () {
    test('Converts correctly to and from JSON using milliseconds', () {
      final tag = CueTag(
        name: 'Verse',
        position: Duration(milliseconds: 15400),
      );

      final json = tag.toJson();
      expect(json['name'], 'Verse');
      expect(json['positionMs'], 15400);

      final decoded = CueTag.fromJson(json);
      expect(decoded.name, 'Verse');
      expect(decoded.position.inMilliseconds, 15400);
    });

    test('Handles missing properties gracefully', () {
      final json = {'name': 'Intro'};
      final decoded = CueTag.fromJson(json);

      expect(decoded.name, 'Intro');
      expect(decoded.position.inMilliseconds, 0);
    });
  });
}
