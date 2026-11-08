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
      aliases: _aliases(map['aliases'] as String?),
      category: map['category'] as String? ?? strength,
    );
  }

  /// Aliases are stored as a JSON list. A field written by hand or by an
  /// older tool may be blank or plain text ("a;b"); read those too, so one
  /// odd row can't break the catalog or an export.
  static List<String> _aliases(String? stored) {
    final text = stored?.trim() ?? '';
    if (text.startsWith('[')) return (jsonDecode(text) as List).cast<String>();
    return [for (final a in text.split(';')) if (a.trim().isNotEmpty) a.trim()];
  }
}
