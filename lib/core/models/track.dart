class Track {
  final String id;
  final String name;
  final String filePath;
  double volume;
  double pan;
  bool mute;
  bool solo;
  bool isClickOrCues;

  Track({
    required this.id,
    required this.name,
    required this.filePath,
    this.volume = 1.0, // Default Unity Gain (1.0 = 100% Volume)
    this.pan = 0.0, // Center
    this.mute = false,
    this.solo = false,
    this.isClickOrCues = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'filePath': filePath,
    'volume': volume,
    'pan': pan,
    'mute': mute,
    'solo': solo,
    'isClickOrCues': isClickOrCues,
  };

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'],
      name: json['name'],
      filePath: json['filePath'],
      volume: (json['volume'] ?? 1.0).toDouble(),
      pan: (json['pan'] ?? 0.0).toDouble(),
      mute: json['mute'] ?? false,
      solo: json['solo'] ?? false,
      isClickOrCues: json['isClickOrCues'] ?? false,
    );
  }

  // Simple factory for dynamic generation
  factory Track.fromFileName(String path, String fileName) {
    bool clickCues = _isSystemTrack(fileName);
    return Track(
      id: fileName,
      name: _cleanName(fileName),
      filePath: path,
      isClickOrCues: clickCues,
      pan: clickCues ? 1.0 : -1.0, // Auto route simple logic
    );
  }

  static bool _isSystemTrack(String name) {
    final lower = name.toLowerCase();
    // Catch common backing track system names: click, clk, cue, cues, guide, guider, guia, metronome
    final regex = RegExp(r'(clic[k]?|clk|cue[s]?|guide[r]?|guia|metronome)');
    return regex.hasMatch(lower);
  }

  static String _cleanName(String name) {
    String n = name.split('.').first;
    return n.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ').trim();
  }
}
