class ActivityEntry {
  final int? id;
  final DateTime date;
  final DateTime timestamp;
  final int tagId; // References Tag.id
  final String? notes;
  final int? severity; // 1 (mild) to 3 (severe), symptoms only

  ActivityEntry({
    this.id,
    required this.date,
    required this.timestamp,
    required this.tagId,
    this.notes,
    this.severity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'timestamp': timestamp.toIso8601String(),
      'tagId': tagId,
      'notes': notes,
      'severity': severity,
    };
  }

  factory ActivityEntry.fromMap(Map<String, dynamic> map) {
    return ActivityEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      tagId: map['tagId'] as int,
      notes: map['notes'] as String?,
      severity: map['severity'] as int?,
    );
  }

  ActivityEntry copyWith({
    int? id,
    DateTime? date,
    DateTime? timestamp,
    int? tagId,
    String? notes,
    int? severity,
  }) {
    return ActivityEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      timestamp: timestamp ?? this.timestamp,
      tagId: tagId ?? this.tagId,
      notes: notes ?? this.notes,
      severity: severity ?? this.severity,
    );
  }
}
