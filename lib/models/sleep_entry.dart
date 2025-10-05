class SleepEntry {
  final int? id;
  final DateTime date;
  final DateTime? wakeUpTime;
  final DateTime? sleepTime;
  final double? totalHours;
  final List<String> tags;

  SleepEntry({
    this.id,
    required this.date,
    this.wakeUpTime,
    this.sleepTime,
    this.totalHours,
    this.tags = const [],
  });

  // Calculate total hours from wake up and sleep time
  double get calculatedHours {
    if (wakeUpTime == null || sleepTime == null) return totalHours ?? 0;

    final duration = wakeUpTime!.difference(sleepTime!);
    return duration.inMinutes / 60.0;
  }

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'wakeUpTime': wakeUpTime?.toIso8601String(),
      'sleepTime': sleepTime?.toIso8601String(),
      'totalHours': totalHours,
      'tags': tags.join(','),
    };
  }

  // Create from Map (database)
  factory SleepEntry.fromMap(Map<String, dynamic> map) {
    return SleepEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      wakeUpTime: map['wakeUpTime'] != null
          ? DateTime.parse(map['wakeUpTime'] as String)
          : null,
      sleepTime: map['sleepTime'] != null
          ? DateTime.parse(map['sleepTime'] as String)
          : null,
      totalHours: map['totalHours'] as double?,
      tags: map['tags'] != null && (map['tags'] as String).isNotEmpty
          ? (map['tags'] as String).split(',')
          : [],
    );
  }

  // Copy with method for updates
  SleepEntry copyWith({
    int? id,
    DateTime? date,
    DateTime? wakeUpTime,
    DateTime? sleepTime,
    double? totalHours,
    List<String>? tags,
  }) {
    return SleepEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      wakeUpTime: wakeUpTime ?? this.wakeUpTime,
      sleepTime: sleepTime ?? this.sleepTime,
      totalHours: totalHours ?? this.totalHours,
      tags: tags ?? this.tags,
    );
  }
}
