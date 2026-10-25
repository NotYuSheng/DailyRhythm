import 'dart:convert';

/// A canonical exercise: one name for its spelling variants.
class ExerciseItem {
  static const strength = 'strength';
  static const cardio = 'cardio';
  static const mobility = 'mobility';

  final int? id;
  final String name;
  final List<String> aliases;
  final String category;

  ExerciseItem({this.id, required this.name, this.aliases = const [], this.category = strength});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'aliases': jsonEncode(aliases),
      'category': category,
    };
  }

  factory ExerciseItem.fromMap(Map<String, dynamic> map) {
    return ExerciseItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      aliases: (jsonDecode(map['aliases'] as String? ?? '[]') as List).cast<String>(),
      category: map['category'] as String? ?? strength,
    );
  }
}
