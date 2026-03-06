import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:command_center_app/core/services/audio_engine_service.dart';
import 'package:command_center_app/core/models/sequence.dart';
import 'package:command_center_app/core/models/track.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSoLoud extends Mock implements SoLoud {
  @override
  void setInaudibleBehavior(SoundHandle handle, bool mustTick, bool kill) {}
}

class MockAudioSource extends Mock implements AudioSource {}

void main() {
  late AudioEngineService audioEngine;
  late MockSoLoud mockSoLoud;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(MockAudioSource());
    // Fallback for SoundHandle Extension Type (usually int)
    registerFallbackValue(0 as SoundHandle);
  });

  setUp(() {
    mockSoLoud = MockSoLoud();
    audioEngine = AudioEngineService();
    audioEngine.mockSoLoud = mockSoLoud;

    when(() => mockSoLoud.init()).thenAnswer((_) async {});
    when(() => mockSoLoud.listPlaybackDevices()).thenReturn([]);
  });

  tearDown(() {
    audioEngine.mockSoLoud = null;
  });

  group('AudioEngineService Unit Tests', () {
    test(
      'init() calls SoLoud.init() and caches initialization properly',
      () async {
        await audioEngine.init();
        verify(() => mockSoLoud.init()).called(1);
      },
    );

    test(
      'loadSequence() reads all tracks into buffers and caches loaded sources',
      () async {
        final mockSource1 = MockAudioSource();
        final mockSource2 = MockAudioSource();

        when(
          () => mockSoLoud.loadFile('path1.wav'),
        ).thenAnswer((_) async => mockSource1);
        when(
          () => mockSoLoud.loadFile('path2.wav'),
        ).thenAnswer((_) async => mockSource2);
        when(() => mockSoLoud.disposeSource(any())).thenAnswer((_) async {});
        when(() => mockSoLoud.stop(any())).thenAnswer((_) async {});

        final sequence = Sequence(
          id: 'seq1',
          name: 'My Sequence',
          folderPath: '/some/path',
          tracks: [
            Track(id: 't1', name: 'Click', filePath: 'path1.wav'),
            Track(id: 't2', name: 'Drums', filePath: 'path2.wav'),
          ],
        );

        await audioEngine.loadSequence(sequence);

        verify(() => mockSoLoud.loadFile('path1.wav')).called(1);
        verify(() => mockSoLoud.loadFile('path2.wav')).called(1);
      },
    );

    test('play() initiates handles for synced sequence successfully', () async {
      final mockSource1 = MockAudioSource();
      final mockHandle1 = 1 as SoundHandle;

      when(
        () => mockSoLoud.loadFile('path1.wav'),
      ).thenAnswer((_) async => mockSource1);
      when(
        () => mockSoLoud.play(
          any(),
          volume: any(named: 'volume'),
          pan: any(named: 'pan'),
          paused: any(named: 'paused'),
        ),
      ).thenAnswer((_) async => mockHandle1);

      when(() => mockSoLoud.setPause(any(), any())).thenAnswer((_) async {});
      when(() => mockSoLoud.setVolume(any(), any())).thenAnswer((_) async {});
      when(() => mockSoLoud.disposeSource(any())).thenAnswer((_) async {});
      when(() => mockSoLoud.stop(any())).thenAnswer((_) async {});

      final sequence = Sequence(
        id: 'seq1',
        name: 'My Sequence',
        folderPath: '/some/path',
        tracks: [
          Track(id: 't1', name: 'Click', filePath: 'path1.wav', volume: 0.8),
        ],
      );

      await audioEngine.loadSequence(sequence);
      await audioEngine.play();

      // Verify play was called initially paused (for syncing)
      verify(
        () => mockSoLoud.play(mockSource1, volume: 0.0, pan: 0.0, paused: true),
      ).called(1);

      // Verify track defaults are applied after sync and unpaused
      verify(() => mockSoLoud.setVolume(mockHandle1, 0.8)).called(1);
      verify(() => mockSoLoud.setPause(mockHandle1, false)).called(1);
    });

    test('pause() instructs active handles to freeze', () async {
      // Setup
      final mockSource1 = MockAudioSource();
      final mockHandle1 = 2 as SoundHandle;

      when(
        () => mockSoLoud.loadFile('track.wav'),
      ).thenAnswer((_) async => mockSource1);
      when(
        () => mockSoLoud.play(
          any(),
          volume: any(named: 'volume'),
          pan: any(named: 'pan'),
          paused: any(named: 'paused'),
        ),
      ).thenAnswer((_) async => mockHandle1);
      when(() => mockSoLoud.setPause(any(), any())).thenAnswer((_) async {});
      when(() => mockSoLoud.setVolume(any(), any())).thenAnswer((_) async {});
      when(() => mockSoLoud.disposeSource(any())).thenAnswer((_) async {});
      when(() => mockSoLoud.stop(any())).thenAnswer((_) async {});

      final sequence = Sequence(
        id: 's',
        name: 'S',
        folderPath: '/',
        tracks: [Track(id: 't', name: 'T', filePath: 'track.wav')],
      );

      await audioEngine.loadSequence(sequence);
      await audioEngine.play(); // Generates internal playing handle dict

      audioEngine.pause();

      // The false is from the play command loop internally, true is from the pause trigger
      verify(() => mockSoLoud.setPause(mockHandle1, true)).called(1);
    });

    test('Track Solo sets volume correctly and silences others', () async {
      final mockSource1 = MockAudioSource();
      final mockSource2 = MockAudioSource();
      final mockHandle1 = 3 as SoundHandle;
      final mockHandle2 = 4 as SoundHandle;

      when(
        () => mockSoLoud.loadFile('track1.wav'),
      ).thenAnswer((_) async => mockSource1);
      when(
        () => mockSoLoud.loadFile('track2.wav'),
      ).thenAnswer((_) async => mockSource2);

      when(
        () => mockSoLoud.play(
          mockSource1,
          volume: any(named: 'volume'),
          pan: any(named: 'pan'),
          paused: true,
        ),
      ).thenAnswer((_) async => mockHandle1);
      when(
        () => mockSoLoud.play(
          mockSource2,
          volume: any(named: 'volume'),
          pan: any(named: 'pan'),
          paused: true,
        ),
      ).thenAnswer((_) async => mockHandle2);

      when(() => mockSoLoud.setPause(any(), any())).thenAnswer((_) async {});
      when(() => mockSoLoud.setVolume(any(), any())).thenAnswer((_) async {});
      when(() => mockSoLoud.disposeSource(any())).thenAnswer((_) async {});
      when(() => mockSoLoud.stop(any())).thenAnswer((_) async {});

      final sequence = Sequence(
        id: 's',
        name: 'S',
        folderPath: '/',
        tracks: [
          Track(id: 't1', name: 'T1', filePath: 'track1.wav', volume: 1.0),
          Track(id: 't2', name: 'T2', filePath: 'track2.wav', volume: 1.0),
        ],
      );

      await audioEngine.loadSequence(sequence);
      await audioEngine.play();

      // Turn on solo for T1
      audioEngine.setTrackSolo('t1', true);

      // Recalculates dynamically
      verify(
        () => mockSoLoud.setVolume(mockHandle1, 1.0),
      ).called(greaterThanOrEqualTo(1));
      verify(
        () => mockSoLoud.setVolume(mockHandle2, 0.0),
      ).called(greaterThanOrEqualTo(1));
    });
  });
}
