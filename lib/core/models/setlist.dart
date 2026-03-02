import 'package:command_center_app/core/models/sequence.dart';

class Setlist {
  final String id;
  String name;
  List<Sequence> sequences;

  Setlist({required this.id, required this.name, this.sequences = const []});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sequences': sequences.map((e) => e.toJson()).toList(),
  };

  factory Setlist.fromJson(Map<String, dynamic> json) {
    return Setlist(
      id: json['id'],
      name: json['name'],
      sequences:
          (json['sequences'] as List?)
              ?.map((e) => Sequence.fromJson(e))
              .toList() ??
          [],
    );
  }
}
