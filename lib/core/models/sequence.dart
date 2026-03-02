import 'track.dart';

class Sequence {
  final String id;
  String name;
  final String folderPath;
  String detectedKey;
  int pitchOverride;
  int pauseAfterSeconds;

  List<CueTag> cueTags;

  List<Track> tracks;

  Sequence({
    required this.id,
    required this.name,
    required this.folderPath,
    this.detectedKey = 'Auto',
    this.pitchOverride = 0,
    this.pauseAfterSeconds = 5,
    this.cueTags = const [],
    required this.tracks,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'folderPath': folderPath,
    'detectedKey': detectedKey,
    'pitchOverride': pitchOverride,
    'pauseAfterSeconds': pauseAfterSeconds,
    'cueTags': cueTags.map((e) => e.toJson()).toList(),
    'tracks': tracks.map((e) => e.toJson()).toList(),
  };

  factory Sequence.fromJson(Map<String, dynamic> json) {
    return Sequence(
      id: json['id'],
      name: json['name'],
      folderPath: json['folderPath'],
      detectedKey: json['detectedKey'] ?? 'Auto',
      pitchOverride: json['pitchOverride'] ?? 0,
      pauseAfterSeconds: json['pauseAfterSeconds'] ?? 5,
      cueTags:
          (json['cueTags'] as List?)?.map((e) => CueTag.fromJson(e)).toList() ??
          [],
      tracks:
          (json['tracks'] as List?)?.map((e) => Track.fromJson(e)).toList() ??
          [],
    );
  }
}

class CueTag {
  String name;
  final Duration position;

  CueTag({required this.name, required this.position});

  Map<String, dynamic> toJson() => {
    'name': name,
    'positionMs': position.inMilliseconds,
  };

  factory CueTag.fromJson(Map<String, dynamic> json) {
    return CueTag(
      name: json['name'],
      position: Duration(milliseconds: json['positionMs'] ?? 0),
    );
  }
}
