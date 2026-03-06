import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:command_center_app/core/models/sequence.dart';
import 'package:command_center_app/core/services/settings_service.dart';
import 'package:flutter/foundation.dart';

class AudioEngineService {
  static final AudioEngineService _instance = AudioEngineService._internal();

  factory AudioEngineService() {
    return _instance;
  }

  AudioEngineService._internal();

  bool _isInitialized = false;
  Sequence? _currentSequence;
  // Maps a track ID to a loaded SoLoud AudioSource
  final Map<String, AudioSource> _loadedSources = {};

  // Maps a track ID to currently playing SoundHandle
  final Map<String, SoundHandle> _playingHandles = {};

  Duration? _pendingSeekPosition;
  bool _globalMuted = false;
  double _globalVolume = 1.0;

  bool get globalMuted => _globalMuted;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await SoLoud.instance.init();
      _isInitialized = true;

      // Load saved output device
      final savedDeviceName = await SettingsService()
          .getAudioOutputDeviceName();
      if (savedDeviceName != null) {
        final devices = SoLoud.instance.listPlaybackDevices();
        for (var device in devices) {
          if (device.name == savedDeviceName) {
            SoLoud.instance.changeDevice(newDevice: device);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to initialize SoLoud: $e');
    }
  }

  /// Loads a Sequence's tracks into memory, ready for playback.
  Future<void> loadSequence(Sequence sequence) async {
    debugPrint(
      'AudioEngineService: Loading sequence ${sequence.name} with ${sequence.tracks.length} tracks.',
    );
    if (!_isInitialized) await init();

    // Stop and unload previous sequence
    await stopAndUnload();

    _currentSequence = sequence;

    for (var track in sequence.tracks) {
      try {
        debugPrint('AudioEngineService: Loading file from ${track.filePath}');
        final source = await SoLoud.instance.loadFile(track.filePath);
        _loadedSources[track.id] = source;
        debugPrint('AudioEngineService: Successfully loaded ${track.id}');
      } catch (e) {
        debugPrint(
          'AudioEngineService: Error loading track ${track.name} at ${track.filePath}: $e',
        );
      }
    }

    debugPrint(
      'AudioEngineService: Finished loading all tracks. Total ready: ${_loadedSources.length}',
    );
  }

  /// Plays all loaded tracks simultaneously.
  Future<void> play() async {
    debugPrint(
      'AudioEngineService: Calling play() - Sequence exists: ${_currentSequence != null} - Loaded Sources: ${_loadedSources.length}',
    );
    if (_currentSequence == null || _loadedSources.isEmpty) return;

    if (_playingHandles.isNotEmpty) {
      for (var handle in _playingHandles.values) {
        SoLoud.instance.setPause(handle, false);
      }
      return;
    }

    // Use a protected flag for Soloud to play without delay if needed,
    // but typically calling play on them sequentially is fast enough for stems if using SoLoud.
    for (var track in _currentSequence!.tracks) {
      if (_loadedSources.containsKey(track.id)) {
        final source = _loadedSources[track.id]!;

        final handle = await SoLoud.instance.play(
          source,
          volume:
              0.0, // Start silenced, let _recalculateVolumes configure it based on solo/mute flags
          pan: track.pan,
          paused: true, // Start paused to sync them
        );
        _playingHandles[track.id] = handle;
      }
    }

    if (_pendingSeekPosition != null) {
      for (var handle in _playingHandles.values) {
        try {
          SoLoud.instance.seek(handle, _pendingSeekPosition!);
        } catch (_) {}
      }
      _pendingSeekPosition = null;
    }

    // Assign proper mix states before unpausing.
    _recalculateVolumes();

    debugPrint(
      'AudioEngineService: Unpausing ${_playingHandles.length} synced tracks...',
    );
    // Now unpause all simultaneously for perfect sync
    for (var handle in _playingHandles.values) {
      SoLoud.instance.setPause(handle, false);
    }
  }

  /// Pauses playback
  void pause() {
    for (var handle in _playingHandles.values) {
      SoLoud.instance.setPause(handle, true);
    }
  }

  /// Seeks playback to a specific position
  void seek(Duration position) {
    if (_playingHandles.isEmpty) {
      _pendingSeekPosition = position;
      return;
    }
    for (var handle in _playingHandles.values) {
      try {
        SoLoud.instance.seek(handle, position);
      } catch (e) {
        debugPrint('AudioEngineService: Failed to seek handle: $e');
      }
    }
  }

  /// Stops playback entirely and resets playheads
  void stop() {
    for (var handle in _playingHandles.values) {
      try {
        SoLoud.instance.stop(handle);
      } catch (_) {}
    }
    _playingHandles.clear();
  }

  /// Disposes of current audio data and clears memory
  Future<void> stopAndUnload() async {
    stop();
    for (var source in _loadedSources.values) {
      SoLoud.instance.disposeSource(source);
    }
    _loadedSources.clear();
    _currentSequence = null;
    _pendingSeekPosition = null;
  }

  /// Private helper to recalculate all active volumes based on Mute and Solo states
  void _recalculateVolumes() {
    if (_currentSequence == null) return;

    bool anySolo = _currentSequence!.tracks.any((t) => t.solo);

    for (var track in _currentSequence!.tracks) {
      if (_playingHandles.containsKey(track.id)) {
        double effectiveVolume = track.volume;

        // Mute state kills volume entirely
        if (track.mute) effectiveVolume = 0.0;

        // If ANY track is soloed, and THIS track is NOT soloed, kill its volume
        if (anySolo && !track.solo) effectiveVolume = 0.0;

        SoLoud.instance.setVolume(_playingHandles[track.id]!, effectiveVolume);
      }
    }
  }

  /// Get current playback position from the first playing handle
  Duration get currentPosition {
    if (_playingHandles.isNotEmpty) {
      try {
        return SoLoud.instance.getPosition(_playingHandles.values.first);
      } catch (e) {
        return _pendingSeekPosition ?? Duration.zero;
      }
    }
    return _pendingSeekPosition ?? Duration.zero;
  }

  /// Get total duration of the loaded sequence
  Duration get totalDuration {
    if (_loadedSources.isNotEmpty) {
      Duration maxDuration = Duration.zero;
      for (var source in _loadedSources.values) {
        final length = SoLoud.instance.getLength(source);
        if (length > maxDuration) {
          maxDuration = length;
        }
      }
      return maxDuration;
    }
    return Duration.zero;
  }

  /// Global Master Volume Adjustment
  void setGlobalVolume(double linearVolume) {
    if (_isInitialized) {
      _globalVolume = linearVolume;
      SoLoud.instance.setGlobalVolume(_globalMuted ? 0.0 : _globalVolume);
    }
  }

  /// Global Master Mute
  void setGlobalMute(bool isMuted) {
    if (_isInitialized) {
      _globalMuted = isMuted;
      SoLoud.instance.setGlobalVolume(_globalMuted ? 0.0 : _globalVolume);
    }
  }

  /// Real-time Volume Adjustment
  void setTrackVolume(String trackId, double linearVolume) {
    if (_currentSequence != null) {
      final track = _currentSequence!.tracks.firstWhere((t) => t.id == trackId);
      track.volume = linearVolume;
      _recalculateVolumes();
    }
  }

  /// Real-time Pan Adjustment (-1.0 to 1.0)
  void setTrackPan(String trackId, double pan) {
    if (_playingHandles.containsKey(trackId)) {
      SoLoud.instance.setPan(_playingHandles[trackId]!, pan);
    }
    if (_currentSequence != null) {
      final track = _currentSequence!.tracks.firstWhere((t) => t.id == trackId);
      track.pan = pan;
    }
  }

  /// Real-time Mute Unmute
  void setTrackMute(String trackId, bool isMuted) {
    if (_currentSequence != null) {
      final track = _currentSequence!.tracks.firstWhere((t) => t.id == trackId);
      track.mute = isMuted;
      _recalculateVolumes();
    }
  }

  /// Real-time Solo toggle (Exclusive Solo)
  void setTrackSolo(String trackId, bool isSoloed) {
    if (_currentSequence != null) {
      // Disengage all other solos if we are activating a new one
      if (isSoloed) {
        for (var t in _currentSequence!.tracks) {
          t.solo = false;
        }
      }

      final track = _currentSequence!.tracks.firstWhere((t) => t.id == trackId);
      track.solo = isSoloed;
      _recalculateVolumes();
    }
  }
}
