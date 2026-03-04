import 'package:flutter_test/flutter_test.dart';
import 'package:command_center_app/core/models/track.dart';

void main() {
  group('Track Model', () {
    test('Track initializes with given values', () {
      final track = Track(
        id: '1',
        name: 'Bass',
        filePath: '/path/to/bass.wav',
        volume: 0.8,
        pan: -0.5,
        mute: true,
        solo: false,
        isClickOrCues: false,
      );

      expect(track.id, '1');
      expect(track.name, 'Bass');
      expect(track.filePath, '/path/to/bass.wav');
      expect(track.volume, 0.8);
      expect(track.pan, -0.5);
      expect(track.mute, isTrue);
      expect(track.solo, isFalse);
      expect(track.isClickOrCues, isFalse);
    });

    test('Track initializes with default values', () {
      final track = Track(
        id: '2',
        name: 'Drums',
        filePath: '/path/to/drums.wav',
      );

      expect(track.volume, 1.0);
      expect(track.pan, 0.0);
      expect(track.mute, isFalse);
      expect(track.solo, isFalse);
      expect(track.isClickOrCues, isFalse);
    });

    test('toJson and fromJson work correctly', () {
      final originalTrack = Track(
        id: '3',
        name: 'Click',
        filePath: '/path/to/click.wav',
        volume: 0.5,
        pan: 0.0,
        isClickOrCues: true,
      );

      final jsonMap = originalTrack.toJson();
      final decodedTrack = Track.fromJson(jsonMap);

      expect(decodedTrack.id, originalTrack.id);
      expect(decodedTrack.name, originalTrack.name);
      expect(decodedTrack.filePath, originalTrack.filePath);
      expect(decodedTrack.volume, originalTrack.volume);
      expect(decodedTrack.pan, originalTrack.pan);
      expect(decodedTrack.isClickOrCues, originalTrack.isClickOrCues);
      expect(decodedTrack.mute, originalTrack.mute);
      expect(decodedTrack.solo, originalTrack.solo);
    });

    test('fromFileName sets isClickOrCues correctly for click tracks', () {
      final track = Track.fromFileName(
        '/path/to/click.wav',
        'click.wav',
        autoRoute: true,
        clickKeywords: 'click, clik, clic',
        cueKeywords: 'cues, guide',
      );

      expect(track.name, equals('click'));
      expect(track.isClickOrCues, isTrue);
    });

    test('fromFileName sets isClickOrCues correctly for cues', () {
      final track = Track.fromFileName(
        '/path/to/cues.wav',
        'cues.wav',
        autoRoute: true,
        clickKeywords: 'click, clik, clic',
        cueKeywords: 'cues, guide',
      );

      expect(track.name, equals('cues'));
      expect(track.isClickOrCues, isTrue);
    });

    test('fromFileName does not mark normal tracks as click/cues', () {
      final track = Track.fromFileName(
        '/path/to/guitar.wav',
        'guitar.wav',
        autoRoute: true,
        clickKeywords: 'click, clik, clic',
        cueKeywords: 'cues, guide',
      );

      expect(track.name, equals('guitar'));
      expect(track.isClickOrCues, isFalse);
    });

    test('fromFileName handles name cleanup correctly', () {
      final track = Track.fromFileName(
        '/path/to/01_guitar_DI_track.wav',
        '01_guitar_DI_track.wav',
      );

      expect(track.name, '01 guitar DI track');
    });
  });
}
