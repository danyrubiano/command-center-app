import 'package:command_center_app/core/models/sequence.dart';

class Setlist {
  final String id;
  String name;
  List<Sequence> sequences;

  Setlist({
    required this.id,
    required this.name,
    this.sequences = const [],
  });
}
