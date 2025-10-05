class ExerciseEntry {
  final int? id;
  final DateTime date;
  final DateTime timestamp;
  final ExerciseType type;

  // Run-specific fields
  final RunType? runType;
  final double? distance; // in km
  final Duration? duration;
  final Duration? pace; // per km

  // Interval-specific fields
  final Duration? intervalDistance;
  final Duration? intervalTime;
  final Duration? restTime;
  final int? intervalCount;

  // Weight lifting-specific fields
  final String? exerciseName;
  final EquipmentType? equipmentType;
  final int? reps;
  final double? weight; // in kg
  final int? sets;

  final String? notes;

  ExerciseEntry({
    this.id,
    required this.date,
    required this.timestamp,
    required this.type,
    this.runType,
    this.distance,
    this.duration,
    this.pace,
    this.intervalDistance,
    this.intervalTime,
    this.restTime,
    this.intervalCount,
    this.exerciseName,
    this.equipmentType,
    this.reps,
    this.weight,
    this.sets,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString(),
      'runType': runType?.toString(),
      'distance': distance,
      'duration': duration?.inSeconds,
      'pace': pace?.inSeconds,
      'intervalDistance': intervalDistance?.inSeconds,
      'intervalTime': intervalTime?.inSeconds,
      'restTime': restTime?.inSeconds,
      'intervalCount': intervalCount,
      'exerciseName': exerciseName,
      'equipmentType': equipmentType?.toString(),
      'reps': reps,
      'weight': weight,
      'sets': sets,
      'notes': notes,
    };
  }

  factory ExerciseEntry.fromMap(Map<String, dynamic> map) {
    return ExerciseEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      type: ExerciseType.values.firstWhere(
        (e) => e.toString() == map['type'],
      ),
      runType: map['runType'] != null
          ? RunType.values.firstWhere((e) => e.toString() == map['runType'])
          : null,
      distance: map['distance'] as double?,
      duration: map['duration'] != null
          ? Duration(seconds: map['duration'] as int)
          : null,
      pace: map['pace'] != null ? Duration(seconds: map['pace'] as int) : null,
      intervalDistance: map['intervalDistance'] != null
          ? Duration(seconds: map['intervalDistance'] as int)
          : null,
      intervalTime: map['intervalTime'] != null
          ? Duration(seconds: map['intervalTime'] as int)
          : null,
      restTime: map['restTime'] != null
          ? Duration(seconds: map['restTime'] as int)
          : null,
      intervalCount: map['intervalCount'] as int?,
      exerciseName: map['exerciseName'] as String?,
      equipmentType: map['equipmentType'] != null
          ? EquipmentType.values.firstWhere((e) => e.toString() == map['equipmentType'])
          : null,
      reps: map['reps'] as int?,
      weight: map['weight'] as double?,
      sets: map['sets'] as int?,
      notes: map['notes'] as String?,
    );
  }

  ExerciseEntry copyWith({
    int? id,
    DateTime? date,
    DateTime? timestamp,
    ExerciseType? type,
    RunType? runType,
    double? distance,
    Duration? duration,
    Duration? pace,
    Duration? intervalDistance,
    Duration? intervalTime,
    Duration? restTime,
    int? intervalCount,
    String? exerciseName,
    EquipmentType? equipmentType,
    int? reps,
    double? weight,
    int? sets,
    String? notes,
  }) {
    return ExerciseEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      runType: runType ?? this.runType,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      pace: pace ?? this.pace,
      intervalDistance: intervalDistance ?? this.intervalDistance,
      intervalTime: intervalTime ?? this.intervalTime,
      restTime: restTime ?? this.restTime,
      intervalCount: intervalCount ?? this.intervalCount,
      exerciseName: exerciseName ?? this.exerciseName,
      equipmentType: equipmentType ?? this.equipmentType,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      sets: sets ?? this.sets,
      notes: notes ?? this.notes,
    );
  }
}

enum ExerciseType {
  run,
  weightLifting,
}

enum RunType {
  interval,
  flat,
}

enum EquipmentType {
  barbell,
  dumbbell,
  kettlebell,
  bodyweight,
  machine,
}

extension EquipmentTypeExtension on EquipmentType {
  String get displayName {
    switch (this) {
      case EquipmentType.barbell:
        return 'Barbell';
      case EquipmentType.dumbbell:
        return 'Dumbbell';
      case EquipmentType.kettlebell:
        return 'Kettlebell';
      case EquipmentType.bodyweight:
        return 'Bodyweight';
      case EquipmentType.machine:
        return 'Machine';
    }
  }

  String get weightLabel {
    switch (this) {
      case EquipmentType.barbell:
        return 'Weight (kg)';
      case EquipmentType.dumbbell:
        return 'Weight per dumbbell (kg)';
      case EquipmentType.kettlebell:
        return 'Weight per kettlebell (kg)';
      case EquipmentType.bodyweight:
        return 'Additional weight (kg)';
      case EquipmentType.machine:
        return 'Weight (kg)';
    }
  }
}
