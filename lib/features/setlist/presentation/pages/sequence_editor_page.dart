import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:command_center_app/core/services/audio_engine_service.dart';
import 'package:command_center_app/core/services/waveform_service.dart';
import 'package:command_center_app/core/models/sequence.dart';
import 'package:just_waveform/just_waveform.dart';

class SequenceEditorPage extends StatefulWidget {
  final Sequence sequence;

  const SequenceEditorPage({super.key, required this.sequence});

  @override
  State<SequenceEditorPage> createState() => _SequenceEditorPageState();
}

class _SequenceEditorPageState extends State<SequenceEditorPage> {
  final AudioEngineService _audioEngine = AudioEngineService();
  bool _isPlaying = false;
  Timer? _timer;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  
  Waveform? _mergedWaveform;
  bool _isExtractingWaveform = false;
  String _waveformMessage = 'Loading sequence...';
  
  late List<CueTag> _cueTags;

  @override
  void initState() {
    super.initState();
    // Copy the existing tags so we can safely edit them in-memory
    _cueTags = List.from(widget.sequence.cueTags);
    _initAudio();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted && _isPlaying) {
         setState(() {
            _currentPosition = _audioEngine.currentPosition;
            _totalDuration = _audioEngine.totalDuration;
         });
      }
    });
  }

  Future<void> _initAudio() async {
    await _audioEngine.init();
    await _audioEngine.loadSequence(widget.sequence);
    
    // Generate true offline waveform peak map
    if (mounted) {
      setState(() {
        _isExtractingWaveform = true;
        _waveformMessage = 'Extracting Offline Waveforms...';
      });
      
      try {
        final wave = await WaveformService.getMergedWaveform(
          widget.sequence,
          onProgress: (p) {
             if (mounted) setState(() => _waveformMessage = 'Analyzing stems: ${(p * 100).toInt()}%');
          }
        );
        if (mounted) setState(() { _mergedWaveform = wave; _isExtractingWaveform = false; });
      } catch (e) {
        if (mounted) setState(() { _waveformMessage = 'Waveform failed: $e'; _isExtractingWaveform = false; });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioEngine.stopAndUnload();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _addTagAtPlayhead() async {
    Duration initialPosition = _currentPosition;
    
    CueTag? newTag = await showDialog<CueTag>(
      context: context,
      builder: (context) {
        String input = '';
        Duration currentTarget = initialPosition;
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            String format(Duration d) {
              String twoDigits(int n) => n.toString().padLeft(2, '0');
              final minutes = twoDigits(d.inMinutes.remainder(60));
              final seconds = twoDigits(d.inSeconds.remainder(60));
              return '$minutes:$seconds';
            }
            return AlertDialog(
              backgroundColor: Theme.of(context).canvasColor,
              title: const Text('Add Cue Tag'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Chorus, Verse 1, Bridge',
                    ),
                    onChanged: (val) => input = val,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white),
                        onPressed: () {
                          if (currentTarget.inSeconds > 0) {
                            setStateBuilder(() => currentTarget -= const Duration(seconds: 1));
                          }
                        }
                      ),
                      Text(format(currentTarget), style: const TextStyle(fontSize: 20)),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () {
                           if (currentTarget < _totalDuration) {
                             setStateBuilder(() => currentTarget += const Duration(seconds: 1));
                           }
                        }
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, CueTag(name: input.isEmpty ? 'Tag' : input, position: currentTarget)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), 
                  child: const Text('Add Tag', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
    
    if (newTag != null) {
      setState(() {
        _cueTags.add(newTag);
        _cueTags.sort((a, b) => a.position.compareTo(b.position));
        widget.sequence.cueTags = _cueTags;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('SEQUENCE EDITOR - ${widget.sequence.name}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Save Configuration', style: TextStyle(color: Colors.white)),
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // 1. Top Section (Timeline & Tags)
            Expanded(
              flex: 2,
              child: _isExtractingWaveform 
                 ? Container(
                     width: double.infinity,
                     decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                     child: Center(
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           const CircularProgressIndicator(color: Colors.blueAccent),
                           const SizedBox(height: 16),
                           Text(_waveformMessage),
                         ],
                       )
                     ),
                   )
                 : _TaggingWaveformSection(
                     currentPosition: _currentPosition,
                     totalDuration: _totalDuration,
                     waveform: _mergedWaveform,
                     cueTags: _cueTags,
                     onSeek: (position) {
                        _audioEngine.seek(position);
                        if (!_isPlaying) {
                           _audioEngine.play();
                           setState(() => _isPlaying = true);
                        }
                     },
                   ),
            ),
            const SizedBox(height: 12),
            
            // 2. Middle Section (Transport & Pitch)
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_location_alt, color: Colors.white),
                        label: const Text('Add Tag at Playhead', style: TextStyle(color: Colors.white)),
                        onPressed: _addTagAtPlayhead,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_formatDuration(_currentPosition), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                            const SizedBox(width: 4),
                            const Text('/', style: TextStyle(fontSize: 12, color: Colors.white54)),
                            const SizedBox(width: 4),
                            Text(_formatDuration(_totalDuration), style: const TextStyle(fontSize: 12, color: Colors.white54)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _circularButton(Icons.skip_previous, Colors.grey, onTap: () {
                               _audioEngine.stop();
                               setState(() {
                                 _isPlaying = false;
                                 _currentPosition = Duration.zero;
                               });
                            }),
                            const SizedBox(width: 16),
                            _circularButton(
                              _isPlaying ? Icons.pause : Icons.play_arrow, 
                              Colors.greenAccent, 
                              size: 56,
                              onTap: () {
                                 if (_isPlaying) {
                                    _audioEngine.pause();
                                 } else {
                                    _audioEngine.play();
                                 }
                                 setState(() => _isPlaying = !_isPlaying);
                              }
                            ),
                            const SizedBox(width: 16),
                            _circularButton(Icons.stop, Colors.redAccent, onTap: () {
                               _audioEngine.stop();
                               setState(() {
                                 _isPlaying = false;
                                 _currentPosition = Duration.zero;
                               });
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Pitch Override (+0)'),
                        Slider(value: 0, min: -12, max: 12, onChanged: (val) {}),
                        const Text('Original Key: Am', style: TextStyle(fontSize: 12, color: Colors.white54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // 3. Bottom Section (Mixer Configuration)
            Expanded(
              flex: 5,
              child: _MixerConfigurationSection(
                sequence: widget.sequence, 
                audioEngine: _audioEngine,
                isPlaying: _isPlaying,
                onStateChanged: () => setState(() {}),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circularButton(IconData icon, Color color, {double size = 48, VoidCallback? onTap}) {
    return GestureDetector(
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
  }
}

class _TaggingWaveformSection extends StatelessWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final Waveform? waveform;
  final List<CueTag> cueTags;
  final void Function(Duration) onSeek;

  const _TaggingWaveformSection({
    required this.currentPosition,
    required this.totalDuration,
    required this.onSeek,
    required this.cueTags,
    this.waveform,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              const Text('WAVEFORM & TAG EDITOR'),
              TextButton(onPressed: () {}, child: const Text('Auto-detect tags from Cues'))
            ],
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black26,
              child: GestureDetector(
                onTapDown: (details) {
                   if (totalDuration.inMilliseconds == 0) return;
                   
                   RenderBox box = context.findRenderObject() as RenderBox;
                   double localX = details.localPosition.dx;
                   double percentage = (localX / box.size.width).clamp(0.0, 1.0);
                   
                   Duration target = Duration(
                     milliseconds: (totalDuration.inMilliseconds * percentage).toInt()
                   );
                   onSeek(target);
                },
                onHorizontalDragUpdate: (details) {
                   if (totalDuration.inMilliseconds == 0) return;
                   
                   RenderBox box = context.findRenderObject() as RenderBox;
                   double localX = details.localPosition.dx;
                   double percentage = (localX / box.size.width).clamp(0.0, 1.0);
                   
                   Duration target = Duration(
                     milliseconds: (totalDuration.inMilliseconds * percentage).toInt()
                   );
                   onSeek(target);
                },
                child: CustomPaint(
                  painter: _TimelinePainter(
                    currentPosition: currentPosition,
                    totalDuration: totalDuration,
                    waveform: waveform,
                    cueTags: cueTags,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final Duration currentPosition;
  final Duration totalDuration;
  final Waveform? waveform;
  final List<CueTag> cueTags;

  _TimelinePainter({
    required this.currentPosition, 
    required this.totalDuration,
    required this.cueTags,
    this.waveform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalDuration.inMilliseconds == 0) return;

    final paintBackground = Paint()..color = Colors.blueAccent.withOpacity(0.1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paintBackground);

    // Calculate progression percentage
    double progress = currentPosition.inMilliseconds / totalDuration.inMilliseconds;
    if (progress > 1.0) progress = 1.0;
    
    // Draw Generated Background Audio Waveform
    final paintWavePlayed = Paint()
      ..color = Colors.blueAccent.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
      
    final paintWaveUnplayed = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    double playheadX = size.width * progress;
    double centerY = size.height / 2;
    
    // Render actual Waveform peaks if they are loaded
    if (waveform != null) {
      final wave = waveform!;
      final pixels = wave.length;
      final step = (pixels / size.width).clamp(1.0, pixels.toDouble());

      for (double x = 0; x < size.width; x += 2.0) {
        int index = (x * step).toInt();
        if (index >= pixels) break;
        
        // The data is max positive peak, min negative peak interleaved if signed correctly,
        // but justwaveform returns min and max amplitudes in an array.
        // It provides getPixelMax() and getPixelMin()
        // Waveform max/min are 16-bit (-32768 to 32767). Map them to canvas height
        double minSample = wave.getPixelMin(index).toDouble();
        double maxSample = wave.getPixelMax(index).toDouble();
        
        double mappedMin = ((minSample / 32768.0) * 3.0).clamp(-1.0, 1.0) * (size.height / 2);
        double mappedMax = ((maxSample / 32768.0) * 3.0).clamp(-1.0, 1.0) * (size.height / 2);
        
        Paint currentPaint = (x <= playheadX) ? paintWavePlayed : paintWaveUnplayed;
        canvas.drawLine(
           Offset(x, centerY + mappedMin), 
           Offset(x, centerY + mappedMax), 
           currentPaint
        );
      }
    } else {
      int numBars = (size.width / 4).floor(); // A bar every 4 pixels
      for (int i = 0; i < numBars; i++) {
          double x = i * 4.0;
          double noise = (math.sin(i * 0.1) * math.cos(i * 0.35) + math.sin(i * 0.05)) * 0.5; 
          double amplitude = 10.0 + (noise.abs() * (size.height / 2 - 10.0));
          
          Paint currentPaint = (x <= playheadX) ? paintWavePlayed : paintWaveUnplayed;
          canvas.drawLine(Offset(x, centerY - amplitude), Offset(x, centerY + amplitude), currentPaint);
      }
    }

    // Draw Cue Tags
    final paintTagLine = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 2.0;

    double lastTopX = -999.0;
    
    for (var tag in cueTags) {
       double tagX = (tag.position.inMilliseconds / totalDuration.inMilliseconds) * size.width;
       
       // Draw vertical marker
       canvas.drawLine(Offset(tagX, 0), Offset(tagX, size.height), paintTagLine);
       
       // Draw text label
       final textSpan = TextSpan(
         text: tag.name,
         style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold, backgroundColor: Colors.black45),
       );
       final textPainter = TextPainter(
         text: textSpan,
         textDirection: TextDirection.ltr,
       );
       textPainter.layout();
       
       // Anti-overlap intelligence
       double textWidth = textPainter.width;
       double yPos = 4.0; 
       
       // If this tag's text physically crashes into the previous Top label, bounce it to the bottom
       if (tagX < lastTopX + 8.0) {
          yPos = size.height - textPainter.height - 4.0;
       } else {
          lastTopX = tagX + textWidth;
       }
       
       textPainter.paint(canvas, Offset(tagX + 4, yPos));
    }

    // Draw Playhead Line
    final paintPlayhead = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2.0;
      
    canvas.drawLine(Offset(playheadX, 0), Offset(playheadX, size.height), paintPlayhead);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition || 
           oldDelegate.totalDuration != totalDuration || 
           oldDelegate.cueTags.length != cueTags.length;
  }
}

class _MixerConfigurationSection extends StatelessWidget {
  final Sequence sequence;
  final AudioEngineService audioEngine;
  final bool isPlaying;
  final VoidCallback onStateChanged;

  const _MixerConfigurationSection({
    required this.sequence, 
    required this.audioEngine,
    required this.isPlaying,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                 mainAxisAlignment: MainAxisAlignment.start,
                 crossAxisAlignment: CrossAxisAlignment.center,
                 children: sequence.tracks.map((track) {
                    return _EditableTrackStrip(
                       name: track.name, 
                       color: track.isClickOrCues ? Colors.yellow : Colors.blueAccent, 
                       initialPan: track.pan,
                       initialVolume: track.volume,
                       trackId: track.id,
                       audioEngine: audioEngine,
                       isPlaying: isPlaying,
                       isMuted: track.mute,
                       isSoloed: track.solo,
                       onStateChanged: onStateChanged,
                    );
                 }).toList(),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Colors.white12, width: 2)),
            ),
            child: _EditableTrackStrip(
               name: 'MASTER', 
               color: Colors.white, 
               initialPan: 0, 
               isMaster: true,
               audioEngine: audioEngine,
               isPlaying: isPlaying,
               isMuted: audioEngine.globalMuted,
               isSoloed: false, 
               onStateChanged: onStateChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableTrackStrip extends StatefulWidget {
  final String name;
  final Color color;
  final bool isMaster;
  final double initialPan;
  final double initialVolume;
  final String? trackId;
  final AudioEngineService? audioEngine;
  final bool isPlaying;
  final bool isMuted;
  final bool isSoloed;
  final VoidCallback? onStateChanged;

  const _EditableTrackStrip({
    required this.name,
    required this.color,
    required this.initialPan,
    this.initialVolume = 1.0,
    this.isMaster = false,
    this.trackId,
    this.audioEngine,
    this.isPlaying = false,
    this.isMuted = false,
    this.isSoloed = false,
    this.onStateChanged,
  });

  @override
  State<_EditableTrackStrip> createState() => _EditableTrackStripState();
}

class _EditableTrackStripState extends State<_EditableTrackStrip> with SingleTickerProviderStateMixin {
  late double _gain;
  late double _pan;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    // Translate Linear Volume (0.0 -> 1.0+) back into dB scale for the UI Slider
    _gain = widget.isMaster ? 0.0 : (widget.initialVolume > 0 ? 20 * (math.log(widget.initialVolume) / math.ln10) : -60.0);
    _pan = widget.initialPan;
    
    // Simulate dynamic audio playback levels bouncing
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300 + (widget.name.length * 40)), // Vary speed per track
      lowerBound: 0.4,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            widget.name.toUpperCase(),
            style: TextStyle(color: widget.color, fontWeight: FontWeight.bold, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          
          if (!widget.isMaster) ...[
            Text('Pan', style: TextStyle(fontSize: 10, color: Colors.white70)),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 2, height: 12, color: Colors.white54),
                Slider(
                  value: _pan,
                  min: -1.0, max: 1.0,
                  onChanged: (v) {
                    setState(() => _pan = v);
                    if (widget.trackId != null && widget.audioEngine != null) {
                       widget.audioEngine!.setTrackPan(widget.trackId!, v);
                    }
                  },
                  activeColor: Colors.white70,
                  inactiveColor: Colors.white24,
                ),
              ],
            ),
          ],
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _miniBtn('M', widget.isMuted ? Colors.redAccent : Colors.grey, onTap: () {
                 if (widget.isMaster && widget.audioEngine != null) {
                    widget.audioEngine!.setGlobalMute(!widget.isMuted);
                 } else if (widget.trackId != null && widget.audioEngine != null) {
                    widget.audioEngine!.setTrackMute(widget.trackId!, !widget.isMuted);
                 }
                 widget.onStateChanged?.call();
              }),
              if (!widget.isMaster)
                _miniBtn('S', widget.isSoloed ? Colors.yellowAccent : Colors.grey, onTap: () {
                   if (widget.trackId != null && widget.audioEngine != null) {
                      widget.audioEngine!.setTrackSolo(widget.trackId!, !widget.isSoloed);
                   }
                   widget.onStateChanged?.call();
                }),
            ],
          ),
          const SizedBox(height: 8),
          
          // Gain Number Readout
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
                // Gain Ruler
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double padding = 24.0;
                    final double trackHeight = constraints.maxHeight - (padding * 2);
                    
                    Widget buildTick(String label, Color color, double value) {
                      final double percent = (value + 60.0) / 72.0;
                      final double bottom = padding + (trackHeight * percent) - 6;
                      return Positioned(
                        bottom: bottom,
                        right: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(label, style: TextStyle(fontSize: 8, color: color)),
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
                  }
                ),
                // Fader
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Slider(
                      min: -60.0,
                      max: 12.0,
                      value: _gain,
                      onChanged: (v) {
                        setState(() {
                          // Snapping feature: if very close to 0, snap exactly to 0
                          _gain = (v < 0.5 && v > -0.5) ? 0.0 : v;
                          
                          if (widget.trackId != null && widget.audioEngine != null && !widget.isMaster) {
                             // Convert DB to Linear volume. Roughly: 
                             // SoLoud volume: 1.0 is default. 
                             // We construct simple exponential for dB: 10 ^ (dB / 20)
                             double linearVol = (math.pow(10, (_gain / 20))).toDouble();
                             widget.audioEngine!.setTrackVolume(widget.trackId!, linearVol);
                          } else if (widget.isMaster && widget.audioEngine != null) {
                             double linearVol = (math.pow(10, (_gain / 20))).toDouble();
                             widget.audioEngine!.setGlobalVolume(linearVol);
                          }
                        });
                      },
                      activeColor: widget.color,
                    ),
                  ),
                ),
                // Dynamic VU Meter Graph
                Container(
                  width: 14,
                  margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white12),
                  ),
                  alignment: Alignment.bottomCenter,
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      // Normalize the Decibel gain (-60 to +12) to a 0.0-1.0 scale
                      double normalizedGain = (_gain + 60) / 72.0;
                      if (_gain <= -59.5) normalizedGain = 0.0;
                      
                      // Apply the simulated audio level bouncing if playing
                      double dynamicLevel = widget.isPlaying 
                           ? (normalizedGain * _animController.value).clamp(0.0, 1.0)
                           : 0.0;
                      
                      return FractionallySizedBox(
                        heightFactor: dynamicLevel,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                widget.color.withOpacity(0.5),
                                widget.color,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBtn(String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black26,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
