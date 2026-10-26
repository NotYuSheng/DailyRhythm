/// Where a health value came from, in order of preference when a day has
/// the same metric from several sources.
class HealthSource {
  HealthSource._();

  static const garminExport = 'garmin_export';
  static const healthConnect = 'health_connect';
  static const healthKit = 'healthkit';
  static const manual = 'manual';

  static const preference = [garminExport, healthConnect, healthKit, manual];

  static int rank(String source) {
    final index = preference.indexOf(source);
    return index < 0 ? preference.length : index;
  }
}

/// One value of one metric on one day (see SCHEMA.md for metric names).
class HealthMetric {
  final DateTime date;
  final String metric;
  final double value;
  final String source;

  HealthMetric({required this.date, required this.metric, required this.value, required this.source});

  Map<String, dynamic> toMap() {
    return {'date': date.toIso8601String(), 'metric': metric, 'value': value, 'source': source};
  }

  factory HealthMetric.fromMap(Map<String, dynamic> map) {
    return HealthMetric(
      date: DateTime.parse(map['date'] as String),
      metric: map['metric'] as String,
      value: (map['value'] as num).toDouble(),
      source: map['source'] as String,
    );
  }
}

class HealthWorkout {
  final int? id;
  final DateTime start;
  final String type;
  final double? durationMin;
  final double? distanceKm;
  final double? kcal;
  final double? avgHr;
  final double? maxHr;
  final String source;

  HealthWorkout({
    this.id,
    required this.start,
    required this.type,
    this.durationMin,
    this.distanceKm,
    this.kcal,
    this.avgHr,
    this.maxHr,
    required this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start': start.toIso8601String(),
      'type': type,
      'duration_min': durationMin,
      'distance_km': distanceKm,
      'kcal': kcal,
      'avg_hr': avgHr,
      'max_hr': maxHr,
      'source': source,
    };
  }

  factory HealthWorkout.fromMap(Map<String, dynamic> map) {
    double? number(String key) => (map[key] as num?)?.toDouble();
    return HealthWorkout(
      id: map['id'] as int?,
      start: DateTime.parse(map['start'] as String),
      type: map['type'] as String,
      durationMin: number('duration_min'),
      distanceKm: number('distance_km'),
      kcal: number('kcal'),
      avgHr: number('avg_hr'),
      maxHr: number('max_hr'),
      source: map['source'] as String,
    );
  }
}
