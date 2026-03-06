import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_waveform/just_waveform.dart';

import 'package:command_center_app/core/models/sequence.dart';
import 'package:command_center_app/core/models/setlist.dart';
import 'package:command_center_app/core/models/track.dart';
import 'package:command_center_app/core/services/audio_engine_service.dart';
import 'package:command_center_app/core/services/waveform_service.dart';
import 'package:command_center_app/core/services/setlist_service.dart';
import 'package:command_center_app/core/services/settings_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class PlayerPage extends StatefulWidget {
  final Setlist? setlist;
  final ValueChanged<Setlist>? onSetlistChanged;
  final ValueChanged<bool>? onPlayStateChanged;

  const PlayerPage({
    super.key,
    this.setlist,
    this.onSetlistChanged,
    this.onPlayStateChanged,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with TickerProviderStateMixin {
  final AudioEngineService _audioEngine = AudioEngineService();

  late Setlist _setlist;
  int _currentSequenceIndex = 0;
  List<Setlist> _availableSetlists = [];

  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _timer;

  Waveform? _mergedWaveform;
  Map<String, Waveform> _trackWaveforms = {};
  bool _isExtractingWaveform = false;
  String _waveformMessage = '';

  bool _isTransitioning = false;
  int _transitionCountdown = 0;
  Timer? _transitionTimer;

  bool _isLoopActive = false;
  bool _isSeeking = false;
  CueTag? _lockedLoopStart;
  CueTag? _lockedLoopEnd;

  // Real-time VU logic
  double _masterVuPeak = 0.0;
  final Map<String, double> _trackVuPeaks = {};

  bool _preventSleepConfig = true;

  @override
  void initState() {
    super.initState();
    _setlist =
        widget.setlist ??
        Setlist(id: 'dummy', name: 'No Setlist', sequences: []);
    _loadAvailableSetlists();
    _setupWakelock();
    HardwareKeyboard.instance.addHandler(_keyHandler);

    if (_setlist.sequences.isNotEmpty) {
      _loadSequence(_setlist.sequences[_currentSequenceIndex]);
    }

    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted && _isPlaying && !_isTransitioning) {
        setState(() {
          if (!_isSeeking) {
            _currentPosition = _audioEngine.currentPosition;

            if (_isLoopActive) {
              _checkLooping();
            } else {
              _checkAutoTransition();
            }
          }

          _updateVuPeak();
        });
      } else if (mounted && !_isPlaying) {
        setState(() {
          if (!_isSeeking) {
            _currentPosition = _audioEngine.currentPosition;
          }
          _masterVuPeak = 0.0;
          _trackVuPeaks.clear();
        });
      }
    });
  }

  bool _keyHandler(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.mediaPlayPause ||
          event.logicalKey == LogicalKeyboardKey.space) {
        _togglePlayPause();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.mediaTrackNext) {
        _skipNext();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious) {
        _skipPrevious();
        return true;
      }
    }
    return false;
  }

  Future<void> _setupWakelock() async {
    _preventSleepConfig = await SettingsService().getPreventScreenSleep();
    _updateWakelockState();
  }

  void _updateWakelockState() {
    if (_preventSleepConfig && _isPlaying) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
    widget.onPlayStateChanged?.call(_isPlaying);
  }

  void _toggleLoop() {
    setState(() {
      _isLoopActive = !_isLoopActive;
      if (_isLoopActive) {
        _lockCurrentLoopSection();
      } else {
        _lockedLoopStart = null;
        _lockedLoopEnd = null;
      }
    });
  }

  void _lockCurrentLoopSection({Duration? overridePosition}) {
    final pos = overridePosition ?? _currentPosition;
    if (_currentSequenceIndex < 0 ||
        _currentSequenceIndex >= _setlist.sequences.length) {
      return;
    }

    final currentSeq = _setlist.sequences[_currentSequenceIndex];
    if (currentSeq.cueTags.isEmpty) {
      _lockedLoopStart = null;
      _lockedLoopEnd = null;
      return;
    }

    CueTag? start;
    CueTag? end;

    for (int i = 0; i < currentSeq.cueTags.length; i++) {
      if (pos.inMilliseconds >= currentSeq.cueTags[i].position.inMilliseconds) {
        start = currentSeq.cueTags[i];
        if (i + 1 < currentSeq.cueTags.length) {
          end = currentSeq.cueTags[i + 1];
        } else {
          end = null;
        }
      }
    }

    _lockedLoopStart = start;
    _lockedLoopEnd = end;
  }

  void _checkLooping() {
    if (_currentSequenceIndex < 0 ||
        _currentSequenceIndex >= _setlist.sequences.length ||
        _isSeeking) {
      return;
    }

    if (_lockedLoopEnd != null) {
      if (_currentPosition.inMilliseconds >=
          _lockedLoopEnd!.position.inMilliseconds - 100) {
        _autoLoopSeek(_lockedLoopStart?.position ?? Duration.zero);
      }
    } else if (_lockedLoopStart != null) {
      if (_totalDuration.inMilliseconds > 0 &&
          _currentPosition.inMilliseconds >=
              _totalDuration.inMilliseconds - 100) {
        _autoLoopSeek(_lockedLoopStart!.position);
      }
    } else {
      // Fallback: If no tags, loop the whole song
      if (_totalDuration.inMilliseconds > 0 &&
          _currentPosition.inMilliseconds >=
              _totalDuration.inMilliseconds - 100) {
        _autoLoopSeek(Duration.zero);
      }
    }
  }

  void _autoLoopSeek(Duration position) {
    if (_isSeeking) return;
    try {
      _isSeeking = true;
      _audioEngine.seek(position);
    } finally {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _isSeeking = false);
      });
    }
  }

  void _manualSeek(Duration position) {
    try {
      _isSeeking = true;
      _audioEngine.seek(position);

      if (_isLoopActive) {
        _lockCurrentLoopSection(overridePosition: position);
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _isSeeking = false);
      });
    }
  }

  void _checkAutoTransition() {
    if (_totalDuration.inMilliseconds > 0 &&
        _currentPosition.inMilliseconds >=
            _totalDuration.inMilliseconds - 100) {
      if (_currentSequenceIndex >= 0 &&
          _currentSequenceIndex < _setlist.sequences.length) {
        final currentSeq = _setlist.sequences[_currentSequenceIndex];
        if (currentSeq.transitionAction == TransitionAction.stop) {
          _audioEngine.stop();
          setState(() {
            _isPlaying = false;
            _currentPosition = Duration.zero;
          });
          return;
        }
      }
      _triggerAutoTransition();
    }
  }

  void _updateVuPeak() {
    if (_totalDuration.inMilliseconds == 0 || !_isPlaying) {
      _masterVuPeak = 0.0;
      _trackVuPeaks.clear();
      return;
    }
    double progress =
        _currentPosition.inMilliseconds / _totalDuration.inMilliseconds;

    // Master Peak based on merged waveform
    if (_mergedWaveform != null) {
      if (_audioEngine.globalMuted) {
        _masterVuPeak = 0.0;
      } else {
        int index = (progress * _mergedWaveform!.length).floor().clamp(
          0,
          _mergedWaveform!.length - 1,
        );
        int dataIdx = index * 2;
        if (dataIdx + 1 < _mergedWaveform!.data.length) {
          int maxVal = _mergedWaveform!.data[dataIdx + 1].abs();
          double peak = (maxVal / 32767.0).clamp(0.0, 1.0);
          _masterVuPeak = (_masterVuPeak * 0.4) + (peak * 0.6);
        }
      }
    }

    // Individual Track Peaks
    if (_currentSequenceIndex >= 0 &&
        _currentSequenceIndex < _setlist.sequences.length) {
      final currentSeq = _setlist.sequences[_currentSequenceIndex];
      bool anySolo = currentSeq.tracks.any((t) => t.solo);

      for (var entry in _trackWaveforms.entries) {
        final trackId = entry.key;

        // Lookup explicitly from Sequence state to enforce visual silence on muted/soloed tracks
        final trackList = currentSeq.tracks.where((t) => t.id == trackId);
        if (trackList.isNotEmpty) {
          final track = trackList.first;
          if (track.mute || (anySolo && !track.solo)) {
            _trackVuPeaks[trackId] = 0.0;
            continue;
          }
        }

        final wf = entry.value;
        int index = (progress * wf.length).floor().clamp(0, wf.length - 1);
        int dataIdx = index * 2;
        if (dataIdx + 1 < wf.data.length) {
          int maxVal = wf.data[dataIdx + 1].abs();
          double peak = (maxVal / 32767.0).clamp(0.0, 1.0);
          double prev = _trackVuPeaks[entry.key] ?? 0.0;
          _trackVuPeaks[entry.key] = (prev * 0.4) + (peak * 0.6);
        }
      }
    }
  }

  void _triggerAutoTransition() {
    if (_isTransitioning) return;

    _audioEngine.stopAndUnload();
    setState(() {
      _isPlaying = false;
      _isTransitioning = true;
    });

    int nextIndex = _currentSequenceIndex + 1;
    if (nextIndex >= _setlist.sequences.length) {
      setState(() {
        _isTransitioning = false;
        _waveformMessage = 'End of Setlist';
      });
      return;
    }

    Sequence currentSeq = _setlist.sequences[_currentSequenceIndex];
    _transitionCountdown = currentSeq.pauseAfterSeconds;

    // Background Load Next
    _loadSequence(_setlist.sequences[nextIndex], startTransition: true);
  }

  Future<void> _loadAvailableSetlists() async {
    final lists = await SetlistService.getSavedSetlists();
    lists.sort((a, b) => b.id.compareTo(a.id));
    if (mounted) {
      setState(() => _availableSetlists = lists);
    }
  }

  Future<void> _loadSequence(
    Sequence sequence, {
    bool autoPlay = false,
    bool startTransition = false,
  }) async {
    setState(() {
      _isExtractingWaveform = true;
      _waveformMessage = 'Loading ${sequence.name}...';
      _mergedWaveform = null;
    });

    try {
      await _audioEngine.loadSequence(sequence);

      setState(() {
        _waveformMessage = 'Analyzing Sequence...';
      });
      _mergedWaveform = await WaveformService.getMergedWaveform(sequence);
      _trackWaveforms = await WaveformService.getTrackWaveforms(sequence);

      if (mounted) {
        setState(() {
          _totalDuration = _audioEngine.totalDuration;
          _currentPosition = Duration.zero;
          _isExtractingWaveform = false;
          _currentSequenceIndex = _setlist.sequences.indexOf(sequence);
        });

        if (startTransition) {
          _startTransitionCountdown();
        } else if (autoPlay) {
          _audioEngine.play();
          setState(() => _isPlaying = true);
          _updateWakelockState();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExtractingWaveform = false;
          _waveformMessage = 'Error loading sequence: $e';
        });
      }
    }
  }

  void _startTransitionCountdown() {
    _transitionTimer?.cancel();
    _transitionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _transitionCountdown--;
        if (_transitionCountdown <= 0) {
          timer.cancel();
          _isTransitioning = false;
          _audioEngine.seek(Duration.zero);
          _audioEngine.play();
          _isPlaying = true;
          _updateWakelockState();
        }
      });
    });
  }

  void _togglePlayPause() {
    if (_isTransitioning) return; // Prevent play during auto-transition

    if (_isPlaying) {
      _audioEngine.pause();
    } else {
      _audioEngine.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
      _updateWakelockState();
    });
  }

  void _stopAndReset() {
    if (_isTransitioning) {
      _transitionTimer?.cancel();
      setState(() => _isTransitioning = false);
    }
    _audioEngine.stop();
    setState(() {
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _updateWakelockState();
    });
  }

  void _skipNext() {
    if (_currentSequenceIndex < _setlist.sequences.length - 1) {
      _stopAndReset();
      _loadSequence(
        _setlist.sequences[_currentSequenceIndex + 1],
        autoPlay: true,
      );
    }
  }

  void _skipPrevious() {
    if (_currentSequenceIndex > 0) {
      _stopAndReset();
      _loadSequence(
        _setlist.sequences[_currentSequenceIndex - 1],
        autoPlay: true,
      );
    } else {
      _audioEngine.seek(Duration.zero);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_keyHandler);
    WakelockPlus.disable();
    _timer?.cancel();
    _transitionTimer?.cancel();
    _audioEngine.stopAndUnload();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    Sequence? currentSequence;
    if (_setlist.sequences.isNotEmpty &&
        _currentSequenceIndex < _setlist.sequences.length) {
      currentSequence = _setlist.sequences[_currentSequenceIndex];
    }
    int nextIndex = (_currentSequenceIndex + 1 < _setlist.sequences.length)
        ? _currentSequenceIndex + 1
        : _currentSequenceIndex;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: currentSequence == null
          ? const Center(
              child: Text(
                'No Setlist Active',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // 1. Top Section (Setlist & Transport)
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).canvasColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          // Setlist Area
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: Colors.white12),
                                ),
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'SETLIST: ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          DropdownButton<String>(
                                            value: _setlist.id == 'dummy'
                                                ? null
                                                : _setlist.id,
                                            dropdownColor: Theme.of(
                                              context,
                                            ).canvasColor,
                                            icon: const Icon(
                                              Icons.arrow_drop_down,
                                              color: Colors.greenAccent,
                                            ),
                                            hint: const Text(
                                              'Select...',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                            items: _availableSetlists
                                                .map(
                                                  (sl) => DropdownMenuItem(
                                                    value: sl.id,
                                                    child: Text(
                                                      sl.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Colors.greenAccent,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                final target =
                                                    _availableSetlists
                                                        .firstWhere(
                                                          (s) => s.id == val,
                                                        );
                                                widget.onSetlistChanged?.call(
                                                  target,
                                                );
                                              }
                                            },
                                            underline: const SizedBox(),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${_currentSequenceIndex + 1}. ${currentSequence.name}',
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'BPM: ${currentSequence.bpm?.toStringAsFixed(1) ?? '--'} | Key: ${currentSequence.detectedKey}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.greenAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Transport Controls
                          Expanded(
                            flex: 3,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _circularButton(
                                  Icons.loop,
                                  _isLoopActive
                                      ? Colors.blueAccent
                                      : Colors.grey,
                                  onTap: _toggleLoop,
                                  tooltip: 'Toggle Loop',
                                ),
                                const SizedBox(width: 16),
                                _circularButton(
                                  Icons.skip_previous,
                                  Colors.grey,
                                  onTap: _skipPrevious,
                                  tooltip: 'Previous Sequence',
                                ),
                                const SizedBox(width: 16),
                                _isTransitioning
                                    ? Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.orange,
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$_transitionCountdown',
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      )
                                    : _circularButton(
                                        _isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        Colors.greenAccent,
                                        size: 64,
                                        onTap: _togglePlayPause,
                                        tooltip: _isPlaying ? 'Pause' : 'Play',
                                      ),
                                const SizedBox(width: 16),
                                _circularButton(
                                  Icons.stop,
                                  Colors.redAccent,
                                  onTap: _stopAndReset,
                                  tooltip: 'Stop',
                                ),
                                const SizedBox(width: 16),
                                _circularButton(
                                  Icons.skip_next,
                                  Colors.grey,
                                  onTap: _skipNext,
                                  tooltip: 'Next Sequence',
                                ),
                              ],
                            ),
                          ),

                          // Pitch / Tempo Area
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: Colors.white12),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'AUTO-NEXT: ${currentSequence.pauseAfterSeconds}s',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Middle Section (Waveform & Timeline)
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).canvasColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        currentSequence.name.toUpperCase(),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (nextIndex != _currentSequenceIndex) ...[
                                      const SizedBox(width: 16),
                                      const Text(
                                        'NEXT: ',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          _setlist.sequences[nextIndex].name
                                              .toUpperCase(),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Text(
                                '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                          Expanded(
                            child: _isExtractingWaveform
                                ? Center(
                                    child: Text(
                                      _waveformMessage,
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      return GestureDetector(
                                        onTapDown: (details) {
                                          if (_totalDuration.inMilliseconds ==
                                              0) {
                                            return;
                                          }
                                          double localX =
                                              details.localPosition.dx;
                                          double percentage =
                                              (localX / constraints.maxWidth)
                                                  .clamp(0.0, 1.0);

                                          // Hit-test: Check if user tapped directly on a section text overlay box
                                          CueTag? tappedTag;
                                          for (var tag
                                              in currentSequence!.cueTags) {
                                            double tagX =
                                                (tag.position.inMilliseconds /
                                                    _totalDuration
                                                        .inMilliseconds) *
                                                constraints.maxWidth;
                                            // Provide a generous 20-pixel physical hit radius bounding box around the text start
                                            if (localX >= tagX - 10 &&
                                                localX <= tagX + 60) {
                                              tappedTag = tag;
                                              break;
                                            }
                                          }

                                          if (tappedTag != null) {
                                            _manualSeek(tappedTag.position);
                                            if (!_isPlaying) {
                                              _togglePlayPause();
                                            }
                                          } else {
                                            Duration target = Duration(
                                              milliseconds:
                                                  (_totalDuration
                                                              .inMilliseconds *
                                                          percentage)
                                                      .toInt(),
                                            );
                                            _manualSeek(target);
                                          }
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          height: double.infinity,
                                          color: Colors.black26,
                                          child: CustomPaint(
                                            painter: _LiveTimelinePainter(
                                              currentPosition: _currentPosition,
                                              totalDuration: _totalDuration,
                                              waveform: _mergedWaveform,
                                              cueTags: currentSequence!.cueTags,
                                              isLoopActive: _isLoopActive,
                                              lockedLoopStart: _lockedLoopStart,
                                              lockedLoopEnd: _lockedLoopEnd,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Bottom Section (Mixer)
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).canvasColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Dynamic Tracks
                          Expanded(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: currentSequence.tracks.length,
                              itemBuilder: (context, index) {
                                Track t = currentSequence!.tracks[index];
                                Color tColor = t.isClickOrCues
                                    ? Colors.yellow
                                    : Colors.blueAccent;
                                return _LiveTrackStrip(
                                  track: t,
                                  color: tColor,
                                  engine: _audioEngine,
                                  currentVuPeak: _trackVuPeaks[t.id] ?? 0.0,
                                  isPlaying: _isPlaying,
                                  isMuted: t.mute,
                                  isSoloed: t.solo,
                                  onStateChanged: () => setState(() {}),
                                );
                              },
                            ),
                          ),

                          // Master Fader
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: Colors.white12,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: _LiveTrackStrip(
                              track: Track(
                                id: 'master',
                                name: 'Master',
                                filePath: '',
                              ),
                              color: Colors.white,
                              isMaster: true,
                              engine: _audioEngine,
                              currentVuPeak: _masterVuPeak,
                              isPlaying: _isPlaying,
                              isMuted: _audioEngine.globalMuted,
                              isSoloed: false,
                              onStateChanged: () => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _circularButton(
    IconData icon,
    Color color, {
    double size = 48,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    Widget button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: Icon(icon, color: color, size: size * 0.5),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}

// =========================================================================
// LIVE MIXER STRIP
// =========================================================================

class _LiveTrackStrip extends StatefulWidget {
  final Track track;
  final Color color;
  final bool isMaster;
  final AudioEngineService engine;
  final double currentVuPeak;
  final bool isPlaying;
  final bool isMuted;
  final bool isSoloed;
  final VoidCallback? onStateChanged;

  const _LiveTrackStrip({
    required this.track,
    required this.color,
    required this.engine,
    required this.currentVuPeak,
    required this.isPlaying,
    required this.isMuted,
    required this.isSoloed,
    this.onStateChanged,
    this.isMaster = false,
  });

  @override
  State<_LiveTrackStrip> createState() => _LiveTrackStripState();
}

class _LiveTrackStripState extends State<_LiveTrackStrip> {
  late double _gain;
  late double _pan;

  @override
  void initState() {
    super.initState();
    _gain = widget.isMaster
        ? 0.0
        : (widget.track.volume > 0
              ? 20 * (math.log(widget.track.volume) / math.ln10)
              : -60.0);
    _pan = widget.track.pan;
  }

  @override
  void didUpdateWidget(_LiveTrackStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) {
      _gain = widget.isMaster
          ? 0.0
          : (widget.track.volume > 0
                ? 20 * (math.log(widget.track.volume) / math.ln10)
                : -60.0);
      _pan = widget.track.pan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            widget.track.name.toUpperCase(),
            style: TextStyle(
              color: widget.color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          if (!widget.isMaster) ...[
            Row(
              children: [
                const SizedBox(width: 4),
                const Text(
                  'L',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(width: 2, height: 12, color: Colors.white54),
                      Slider(
                        value: _pan,
                        min: -1.0,
                        max: 1.0,
                        onChanged: (v) {
                          setState(() => _pan = v);
                          widget.engine.setTrackPan(widget.track.id, v);
                        },
                        activeColor: Colors.white70,
                        inactiveColor: Colors.white24,
                      ),
                    ],
                  ),
                ),
                const Text(
                  'R',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _miniBtn(
                'M',
                Colors.red,
                active: widget.isMaster
                    ? widget.engine.globalMuted
                    : widget.isMuted,
                onTap: () {
                  if (widget.isMaster) {
                    widget.engine.setGlobalMute(!widget.engine.globalMuted);
                  } else {
                    widget.engine.setTrackMute(
                      widget.track.id,
                      !widget.isMuted,
                    );
                  }
                  widget.onStateChanged?.call();
                },
              ),
              const SizedBox(width: 8),
              if (!widget.isMaster)
                _miniBtn(
                  'S',
                  Colors.yellow,
                  active: widget.isSoloed,
                  onTap: () {
                    widget.engine.setTrackSolo(
                      widget.track.id,
                      !widget.isSoloed,
                    );
                    widget.onStateChanged?.call();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            _gain > 0
                ? '+${_gain.toStringAsFixed(1)} dB'
                : '${_gain.toStringAsFixed(1)} dB',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _gain == 0.0 ? Colors.greenAccent : Colors.white,
            ),
          ),
          const SizedBox(height: 4),

          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double padding = 24.0;
                    final double trackHeight =
                        constraints.maxHeight - (padding * 2);

                    Widget buildTick(String label, Color color, double value) {
                      final double percent = (value + 60.0) / 72.0;
                      final double bottom =
                          padding + (trackHeight * percent) - 6;
                      return Positioned(
                        bottom: bottom,
                        right: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: TextStyle(fontSize: 8, color: color),
                            ),
                            const SizedBox(width: 4),
                            Container(width: 6, height: 1, color: color),
                          ],
                        ),
                      );
                    }

                    return SizedBox(
                      width: 28,
                      child: Stack(
                        children: [
                          buildTick('+12', Colors.white54, 12.0),
                          buildTick('  0', Colors.greenAccent, 0.0),
                          buildTick('-12', Colors.white54, -12.0),
                          buildTick('-24', Colors.white54, -24.0),
                          buildTick('-60', Colors.white54, -60.0),
                        ],
                      ),
                    );
                  },
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double padding = 24.0;
                      final double trackHeight =
                          constraints.maxHeight - (padding * 2);

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (details) {
                          setState(() {
                            final double dbPerPixel = 72.0 / trackHeight;
                            _gain -= details.delta.dy * dbPerPixel;
                            _gain = _gain.clamp(-60.0, 12.0);

                            if (_gain < 0.5 && _gain > -0.5) _gain = 0.0;

                            double linearVol = (math.pow(
                              10,
                              (_gain / 20),
                            )).toDouble();
                            if (_gain <= -59.5) linearVol = 0.0;
                            if (widget.isMaster) {
                              widget.engine.setGlobalVolume(linearVol);
                            } else {
                              widget.engine.setTrackVolume(
                                widget.track.id,
                                linearVol,
                              );
                            }
                          });
                        },
                        onVerticalDragDown: (details) {
                          setState(() {
                            double posY = details.localPosition.dy - padding;
                            posY = posY.clamp(0.0, trackHeight);
                            final double percent = 1.0 - (posY / trackHeight);
                            _gain = -60.0 + (percent * 72.0);
                            _gain = _gain.clamp(-60.0, 12.0);

                            if (_gain < 0.5 && _gain > -0.5) _gain = 0.0;

                            double linearVol = (math.pow(
                              10,
                              (_gain / 20),
                            )).toDouble();
                            if (_gain <= -59.5) linearVol = 0.0;
                            if (widget.isMaster) {
                              widget.engine.setGlobalVolume(linearVol);
                            } else {
                              widget.engine.setTrackVolume(
                                widget.track.id,
                                linearVol,
                              );
                            }
                          });
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: padding,
                              bottom: padding,
                              child: Container(
                                width: 8,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.white24),
                                ),
                              ),
                            ),
                            Positioned(
                              top:
                                  padding +
                                  (trackHeight *
                                      (1.0 - ((_gain + 60.0) / 72.0))) -
                                  20,
                              left: 4,
                              right: 4,
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: widget.color.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Container(
                                    height: 4,
                                    width: double.infinity,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  width: 14,
                  margin: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: Colors.white12),
                  ),
                  alignment: Alignment.bottomCenter,
                  child: Builder(
                    builder: (context) {
                      double normalizedGain = (_gain + 60) / 72.0;
                      if (_gain <= -59.5) normalizedGain = 0.0;

                      double dynamicLevel =
                          widget.isPlaying && !widget.track.mute
                          ? (normalizedGain * widget.currentVuPeak).clamp(
                              0.0,
                              1.0,
                            )
                          : 0.0;

                      return FractionallySizedBox(
                        heightFactor: dynamicLevel,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                widget.color.withValues(alpha: 0.5),
                                widget.color,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBtn(
    String label,
    Color color, {
    bool active = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.1),
          border: Border.all(
            color: active ? color : color.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// LIVE TIMELINE PAINTER
// =========================================================================

class _LiveTimelinePainter extends CustomPainter {
  final Duration currentPosition;
  final Duration totalDuration;
  final Waveform? waveform;
  final List<CueTag> cueTags;
  final bool isLoopActive;
  final CueTag? lockedLoopStart;
  final CueTag? lockedLoopEnd;

  _LiveTimelinePainter({
    required this.currentPosition,
    required this.totalDuration,
    required this.cueTags,
    this.waveform,
    this.isLoopActive = false,
    this.lockedLoopStart,
    this.lockedLoopEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalDuration.inMilliseconds == 0) return;

    final paintBackground = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.1);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paintBackground,
    );

    double progress =
        currentPosition.inMilliseconds / totalDuration.inMilliseconds;
    if (progress > 1.0) progress = 1.0;

    final paintWavePlayed = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final paintWaveUnplayed = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    double playheadX = size.width * progress;
    double centerY = size.height / 2;

    if (waveform != null) {
      final wave = waveform!;
      final pixels = wave.length;
      final step = (pixels / size.width).clamp(1.0, pixels.toDouble());

      for (double x = 0; x < size.width; x += 2.0) {
        int index = (x * step).toInt();
        if (index >= pixels) break;

        double minSample = wave.getPixelMin(index).toDouble();
        double maxSample = wave.getPixelMax(index).toDouble();

        double mappedMin = (minSample / 32768.0) * (size.height / 2) * 3.0;
        double mappedMax = (maxSample / 32768.0) * (size.height / 2) * 3.0;

        mappedMin = mappedMin.clamp(-size.height / 2, size.height / 2);
        mappedMax = mappedMax.clamp(-size.height / 2, size.height / 2);

        Paint currentPaint = (x <= playheadX)
            ? paintWavePlayed
            : paintWaveUnplayed;
        canvas.drawLine(
          Offset(x, centerY + mappedMin),
          Offset(x, centerY + mappedMax),
          currentPaint,
        );
      }
    }

    // Draw Cue Tags
    final paintTagLine = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 2.0;
    double lastTopX = -999.0;

    for (var tag in cueTags) {
      double tagX =
          (tag.position.inMilliseconds / totalDuration.inMilliseconds) *
          size.width;

      canvas.drawLine(Offset(tagX, 0), Offset(tagX, size.height), paintTagLine);

      final textSpan = TextSpan(
        text: tag.name,
        style: const TextStyle(
          color: Colors.orangeAccent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black45,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      double yPos = 4.0;
      if (tagX < lastTopX + 8.0) {
        yPos = size.height - textPainter.height - 4.0;
      } else {
        lastTopX = tagX + textPainter.width;
      }
      textPainter.paint(canvas, Offset(tagX + 4, yPos));
    }

    // Draw Active Loop Region
    if (isLoopActive) {
      double startX = 0;
      double endX = size.width;

      if (lockedLoopStart != null) {
        startX =
            (lockedLoopStart!.position.inMilliseconds /
                totalDuration.inMilliseconds) *
            size.width;
      }
      if (lockedLoopEnd != null) {
        endX =
            (lockedLoopEnd!.position.inMilliseconds /
                totalDuration.inMilliseconds) *
            size.width;
      }

      final Rect loopRect = Rect.fromLTRB(startX, 0, endX, size.height);
      final Paint loopPaint = Paint()
        ..color = Colors.blueAccent.withValues(alpha: 0.2);
      canvas.drawRect(loopRect, loopPaint);
    }

    // Draw Playhead Line
    final paintPlayhead = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      paintPlayhead,
    );
  }

  @override
  bool shouldRepaint(covariant _LiveTimelinePainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition ||
        oldDelegate.totalDuration != totalDuration ||
        oldDelegate.cueTags.length != cueTags.length ||
        oldDelegate.isLoopActive != isLoopActive;
  }
}
