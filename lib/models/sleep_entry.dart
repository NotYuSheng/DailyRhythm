class SleepEntry {
  final int? id;
  final DateTime date;
  final DateTime? wakeUpTime;
  final DateTime? sleepTime;
  final double? totalHours;
  final double? napHours;
  final List<String> tags;

  SleepEntry({
    this.id,
    required this.date,
    this.wakeUpTime,
    this.sleepTime,
    this.totalHours,
    this.napHours,
    this.tags = const [],
  });

  // Calculate total hours from wake up and sleep time
  double get calculatedHours {
    if (wakeUpTime == null || sleepTime == null) return totalHours ?? 0;

    var duration = wakeUpTime!.difference(sleepTime!);

    // If wake time is before sleep time, assume it's the next day
    if (duration.isNegative) {
      duration = duration + const Duration(days: 1);
    }

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
      'napHours': napHours,
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
      napHours: map['napHours'] as double?,
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
    double? napHours,
    List<String>? tags,
  }) {
    return SleepEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      wakeUpTime: wakeUpTime ?? this.wakeUpTime,
      sleepTime: sleepTime ?? this.sleepTime,
      totalHours: totalHours ?? this.totalHours,
      napHours: napHours ?? this.napHours,
      tags: tags ?? this.tags,
    );
  }
}
