class TaskEntry {
  final int? id;
  final DateTime date;
  final DateTime timestamp;
  final TaskType taskType;
  final String? notes;

  TaskEntry({
    this.id,
    required this.date,
    required this.timestamp,
    required this.taskType,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'timestamp': timestamp.toIso8601String(),
      'taskType': taskType.toString(),
      'notes': notes,
    };
  }

  factory TaskEntry.fromMap(Map<String, dynamic> map) {
    return TaskEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      taskType: TaskType.values.firstWhere(
        (e) => e.toString() == map['taskType'],
        orElse: () => TaskType.changedBedsheet,
      ),
      notes: map['notes'] as String?,
    );
  }

  TaskEntry copyWith({
    int? id,
    DateTime? date,
    DateTime? timestamp,
    TaskType? taskType,
    String? notes,
  }) {
    return TaskEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      timestamp: timestamp ?? this.timestamp,
      taskType: taskType ?? this.taskType,
      notes: notes ?? this.notes,
    );
  }
}

enum TaskType {
  haircut,
  changedBedsheet,
}

extension TaskTypeExtension on TaskType {
  String get displayName {
    switch (this) {
      case TaskType.haircut:
        return 'Haircut';
      case TaskType.changedBedsheet:
        return 'Changed Bedsheet';
    }
  }
}
