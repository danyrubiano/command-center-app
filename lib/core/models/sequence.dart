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
}

class CueTag {
  String name;
  final Duration position;
  
  CueTag({required this.name, required this.position});
}
