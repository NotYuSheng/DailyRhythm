class NapEntry {
  final int? id;
  final DateTime date;
  final DateTime startTime;
  final double durationHours;
  final List<String> tags;

  NapEntry({
    this.id,
    required this.date,
    required this.startTime,
    required this.durationHours,
    this.tags = const [],
  });

  // Get end time based on duration
  DateTime get endTime {
    final minutes = (durationHours * 60).round();
    return startTime.add(Duration(minutes: minutes));
  }

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'startTime': startTime.toIso8601String(),
      'durationHours': durationHours,
      'tags': tags.join(','),
    };
  }

  // Create from Map (database)
  factory NapEntry.fromMap(Map<String, dynamic> map) {
    return NapEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      startTime: DateTime.parse(map['startTime'] as String),
      durationHours: map['durationHours'] as double,
      tags: map['tags'] != null && (map['tags'] as String).isNotEmpty
          ? (map['tags'] as String).split(',')
          : [],
    );
  }

  // Copy with method for updates
  NapEntry copyWith({
    int? id,
    DateTime? date,
    DateTime? startTime,
    double? durationHours,
    List<String>? tags,
  }) {
    return NapEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      durationHours: durationHours ?? this.durationHours,
      tags: tags ?? this.tags,
    );
  }
}
