/// A moment in the day: free text with an optional mood of its own and the
/// activities or symptoms it is about.
class JournalEntry {
  final int? id;
  final DateTime date;
  final DateTime? time; // null when only the day is known (Daylio imports)
  final String text;
  final int? mood; // 1-5; null when the moment has no mood of its own
  final String source; // 'app' or 'daylio'
  final List<int> tagIds;
  final DateTime createdAt;

  JournalEntry({
    this.id,
    required this.date,
    this.time,
    this.text = '',
    this.mood,
    this.source = 'app',
    this.tagIds = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'time': time?.toIso8601String(),
      'text': text,
      'mood': mood,
      'source': source,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map, {List<int> tagIds = const []}) {
    return JournalEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      time: map['time'] != null ? DateTime.parse(map['time'] as String) : null,
      text: map['text'] as String? ?? '',
      mood: map['mood'] as int?,
      source: map['source'] as String? ?? 'app',
      tagIds: tagIds,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  JournalEntry copyWith({
    int? id,
    DateTime? date,
    DateTime? time,
    String? text,
    int? mood,
    String? source,
    List<int>? tagIds,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      text: text ?? this.text,
      mood: mood ?? this.mood,
      source: source ?? this.source,
      tagIds: tagIds ?? this.tagIds,
      createdAt: createdAt,
    );
  }
}
