class MoodEntry {
  final int? id;
  final DateTime date;
  final DateTime timestamp;
  final int moodLevel; // 1-5 (1=Very Bad, 2=Bad, 3=Okay, 4=Good, 5=Great)
  final String emoji;
  final String? notes;

  MoodEntry({
    this.id,
    required this.date,
    required this.timestamp,
    required this.moodLevel,
    required this.emoji,
    this.notes,
  });

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'timestamp': timestamp.toIso8601String(),
      'moodLevel': moodLevel,
      'emoji': emoji,
      'notes': notes,
    };
  }

  // Create from Map (database)
  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      moodLevel: map['moodLevel'] as int,
      emoji: map['emoji'] as String,
      notes: map['notes'] as String?,
    );
  }

  // Copy with method for updates
  MoodEntry copyWith({
    int? id,
    DateTime? date,
    DateTime? timestamp,
    int? moodLevel,
    String? emoji,
    String? notes,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      timestamp: timestamp ?? this.timestamp,
      moodLevel: moodLevel ?? this.moodLevel,
      emoji: emoji ?? this.emoji,
      notes: notes ?? this.notes,
    );
  }

  // Helper to get mood label
  String get moodLabel {
    switch (moodLevel) {
      case 1:
        return 'Very Bad';
      case 2:
        return 'Bad';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Great';
      default:
        return 'Unknown';
    }
  }
}
