import 'package:flutter/material.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // 1. Top Section (Setlist & Transport)
            const Expanded(
              flex: 2,
              child: _TopSection(),
            ),
            const SizedBox(height: 12),
            
            // 2. Middle Section (Waveform & Timeline)
            const Expanded(
              flex: 2,
              child: _WaveformSection(),
            ),
            const SizedBox(height: 12),
            
            // 3. Bottom Section (Mixer)
            const Expanded(
              flex: 5,
              child: _MixerSection(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopSection extends StatelessWidget {
  const _TopSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Setlist Area Placeholder
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.white12)),
              ),
              child: const Center(
                child: Text('SETLIST\n1. Song Name [Detected: Am]', textAlign: TextAlign.center),
              ),
            ),
          ),
          
          // Transport Controls
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _circularButton(Icons.skip_previous, Colors.grey),
                const SizedBox(width: 16),
                _circularButton(Icons.play_arrow, Colors.greenAccent, size: 64),
                const SizedBox(width: 16),
                _circularButton(Icons.stop, Colors.redAccent),
                const SizedBox(width: 16),
                _circularButton(Icons.skip_next, Colors.grey),
              ],
            ),
          ),
          
          // Pitch / Tempo / Master Area
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Colors.white12)),
              ),
              child: const Center(
                child: Text('PITCH: +0\nKEY: Am', textAlign: TextAlign.center),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circularButton(IconData icon, Color color, {double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}

class _WaveformSection extends StatelessWidget {
  const _WaveformSection();

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
          const Text('TIMELINE & WAVEFORM (Next: Chorus)'),
          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                height: 100,
                color: Colors.blueAccent.withOpacity(0.1),
                child: const Center(child: Text('[ WAVEFORM RENDERING AREA ]')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MixerSection extends StatelessWidget {
  const _MixerSection();

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
          // Dynamic Tracks Scroll Options
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                 mainAxisAlignment: MainAxisAlignment.start,
                 crossAxisAlignment: CrossAxisAlignment.center,
                // Implementing strict sorting concept here visually
                children: const [
                  _TrackStrip(name: 'Click', color: Colors.yellow),
                  _TrackStrip(name: 'Cues', color: Colors.green),
                  _TrackStrip(name: 'Drums', color: Colors.orange),
                  _TrackStrip(name: 'Bass', color: Colors.blue),
                  _TrackStrip(name: 'Synths', color: Colors.purple),
                  _TrackStrip(name: 'Guitars', color: Colors.red),
                ],
              ),
            ),
          ),
          
          // Master Fader (Pinned to Right)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Colors.white12, width: 2)),
            ),
            child: const _TrackStrip(name: 'MASTER', color: Colors.white, isMaster: true),
          ),
        ],
      ),
    );
  }
}

class _TrackStrip extends StatefulWidget {
  final String name;
  final Color color;
  final bool isMaster;

  const _TrackStrip({
    required this.name,
    required this.color,
    this.isMaster = false,
  });

  @override
  State<_TrackStrip> createState() => _TrackStripState();
}

class _TrackStripState extends State<_TrackStrip> with SingleTickerProviderStateMixin {
  late double _gain;
  late double _pan;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _gain = widget.isMaster ? 0.0 : -6.0;
    _pan = 0.0;
    
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
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Track Name
          Text(
            widget.name.toUpperCase(),
            style: TextStyle(
              color: widget.color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          
          if (!widget.isMaster) ...[
            Text('Pan', style: TextStyle(fontSize: 10, color: Colors.white70)),
            Slider(
              value: _pan,
              min: -1.0, max: 1.0,
              onChanged: (v) {
                setState(() => _pan = v);
              },
              activeColor: Colors.white70,
              inactiveColor: Colors.white24,
            ),
            const SizedBox(height: 8),
            // Mute / Solo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _miniBtn('M', Colors.grey),
                _miniBtn('S', Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
          ],
          
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
          
          // Fader & Graph Column
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gain Ruler
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('+12', style: TextStyle(fontSize: 8, color: Colors.white54)),
                      Text('  0', style: TextStyle(fontSize: 8, color: Colors.greenAccent)),
                      Text('-12', style: TextStyle(fontSize: 8, color: Colors.white54)),
                      Text('-24', style: TextStyle(fontSize: 8, color: Colors.white54)),
                      Text('-60', style: TextStyle(fontSize: 8, color: Colors.white54)),
                    ],
                  ),
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
                      // Apply the simulated audio level bouncing
                      double dynamicLevel = (normalizedGain * _animController.value).clamp(0.0, 1.0);
                      
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

  Widget _miniBtn(String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black26,
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
