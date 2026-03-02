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
  factory Track.fromFileName(
    String path,
    String fileName, {
    bool autoRoute = true,
    String clickKeywords = 'click, clk, metronome',
    String cueKeywords = 'cue, cues, guide, guider, guia, vocal, english',
  }) {
    bool clickCues = _isSystemTrack(fileName, clickKeywords, cueKeywords);
    double assignedPan = 0.0;

    if (autoRoute) {
      assignedPan = clickCues ? 1.0 : -1.0;
    }

    return Track(
      id: fileName,
      name: _cleanName(fileName),
      filePath: path,
      isClickOrCues: clickCues,
      pan: assignedPan,
    );
  }

  static bool _isSystemTrack(
    String name,
    String clickKeywords,
    String cueKeywords,
  ) {
    final lower = name.toLowerCase();

    // Split combined keywords strings by commas, trim spaces, drop empty slots
    final allKeywordsStringList = [
      ...clickKeywords.split(','),
      ...cueKeywords.split(','),
    ];
    final allKeywords = allKeywordsStringList
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();

    if (allKeywords.isEmpty) return false;

    // Create robust regex string logic dynamically by escaping any strange user input
    final escapedKeywords = allKeywords.map((s) => RegExp.escape(s)).join('|');
    final regex = RegExp(r'(' + escapedKeywords + r')');

    return regex.hasMatch(lower);
  }

  static String _cleanName(String name) {
    String n = name.split('.').first;
    return n.replaceAll(RegExp(r'[^a-zA-Z0-9 \-]'), ' ').trim();
  }
}
