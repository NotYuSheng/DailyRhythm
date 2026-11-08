import 'dart:convert';
import 'dart:isolate';

import 'package:archive/archive.dart';

import 'models/health_metric.dart';

/// What a Garmin export holds, as the app's health records.
class GarminImport {
  const GarminImport(this.metrics, this.workouts);

  final List<HealthMetric> metrics;
  final List<HealthWorkout> workouts;

  int get days => {for (final m in metrics) m.date}.length;
}

/// Reads daily health metrics and workouts from a Garmin Connect "Export
/// Your Data" zip, like `tools/daylio_migration/garmin.py`.
///
/// Only the wellness and activity files are read; profile, email and
/// consent files are ignored. The format is undocumented, so every field is
/// optional and missing or negative ("no data") values are skipped. Sleep
/// belongs to the date it ended on, as a day's sleep is the night before.
class GarminExportReader {
  static const source = HealthSource.garminExport;

  static final _files = {
    'daily': RegExp(r'(^|/)UDSFile_[^/]*\.json$'),
    'sleep': RegExp(r'(^|/)[^/]*_sleepData\.json$'),
    'health': RegExp(r'(^|/)[^/]*_healthStatusData\.json$'),
    'activities': RegExp(r'(^|/)[^/]*_summarizedActivities\.json$'),
  };

  static const _healthNames = {
    'HRV': 'hrv',
    'HR': 'sleep_hr',
    'RESPIRATION': 'sleep_respiration',
    'SPO2': 'spo2',
    'SKIN_TEMP_C': 'skin_temp_c',
  };

  /// Reads the zip in [bytes]. Throws [FormatException] if it holds none of
  /// the known files.
  static GarminImport readZip(List<int> bytes) => _read(ZipDecoder().decodeBytes(bytes));

  /// Reads the zip at [path] on another isolate, streaming it from disk:
  /// exports can be gigabytes (mostly FIT files, which are never unpacked).
  static Future<GarminImport> readZipFile(String path) => Isolate.run(() {
        final input = InputFileStream(path);
        try {
          return _read(ZipDecoder().decodeStream(input));
        } finally {
          input.closeSync();
        }
      });

  static GarminImport _read(Archive archive) {
    final records = <String, List<Map<String, dynamic>>>{for (final k in _files.keys) k: []};
    var found = false;
    for (final file in archive) {
      if (!file.isFile) continue;
      for (final MapEntry(key: kind, value: pattern) in _files.entries) {
        if (!pattern.hasMatch(file.name)) continue;
        found = true;
        final data = jsonDecode(utf8.decode(file.content)) as List;
        if (kind == 'activities') {
          for (final block in data.cast<Map<String, dynamic>>()) {
            records[kind]!.addAll(((block['summarizedActivitiesExport'] as List?) ?? const []).cast<Map<String, dynamic>>());
          }
        } else {
          records[kind]!.addAll(data.cast<Map<String, dynamic>>());
        }
      }
    }
    if (!found) throw const FormatException('This doesn’t look like a Garmin export: no wellness or activity files');
    return fromRecords(records);
  }

  /// Turns the export's records, by file kind, into metrics and workouts.
  static GarminImport fromRecords(Map<String, List<Map<String, dynamic>>> records) {
    final metrics = <(DateTime, String), double>{};
    void put(String? date, String name, Object? value) {
      final number = _number(value);
      if (date == null || number == null) return;
      metrics[(DateTime.parse(date), name)] = number;
    }

    for (final r in records['daily'] ?? const <Map<String, dynamic>>[]) {
      final date = r['calendarDate'] as String?;
      put(date, 'steps', r['totalSteps']);
      put(date, 'resting_hr', r['restingHeartRate']);
      put(date, 'active_kcal', r['activeKilocalories']);
      final moderate = _number(r['moderateIntensityMinutes']);
      final vigorous = _number(r['vigorousIntensityMinutes']);
      // Garmin counts vigorous minutes double.
      if (moderate != null || vigorous != null) put(date, 'intensity_minutes', (moderate ?? 0) + 2 * (vigorous ?? 0));
      final stress = ((r['allDayStress'] as Map?)?['aggregatorList'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .where((a) => a['type'] == 'TOTAL')
          .firstOrNull;
      put(date, 'stress_avg', stress?['averageStressLevel']);
      put(date, 'stress_max', stress?['maxStressLevel']);
      final battery = r['bodyBattery'] as Map<String, dynamic>? ?? const {};
      final stats = {
        for (final s in (battery['bodyBatteryStatList'] as List? ?? const []).cast<Map<String, dynamic>>())
          s['bodyBatteryStatType']: s['statsValue'],
      };
      put(date, 'body_battery_high', stats['HIGHEST']);
      put(date, 'body_battery_low', stats['LOWEST']);
      put(date, 'body_battery_charged', battery['chargedValue']);
      put(date, 'body_battery_drained', battery['drainedValue']);
      put(date, 'respiration_waking', (r['respiration'] as Map?)?['avgWakingRespirationValue']);
    }

    for (final r in records['sleep'] ?? const <Map<String, dynamic>>[]) {
      final date = r['calendarDate'] as String?;
      final stages = [for (final k in ['deepSleepSeconds', 'lightSleepSeconds', 'remSleepSeconds']) _number(r[k])];
      if (date == null || stages.every((s) => s == null || s == 0)) continue; // nap-only or unmeasured night
      put(date, 'sleep_minutes', stages.fold<double>(0, (sum, s) => sum + (s ?? 0)) / 60);
      put(date, 'sleep_deep_minutes', (stages[0] ?? 0) / 60);
      put(date, 'sleep_light_minutes', (stages[1] ?? 0) / 60);
      put(date, 'sleep_rem_minutes', (stages[2] ?? 0) / 60);
      put(date, 'sleep_awake_minutes', (_number(r['awakeSleepSeconds']) ?? 0) / 60);
      put(date, 'sleep_score', (r['sleepScores'] as Map?)?['overallScore']);
      put(date, 'sleep_stress_avg', r['avgSleepStress']);
    }

    for (final r in records['health'] ?? const <Map<String, dynamic>>[]) {
      final date = r['calendarDate'] as String?;
      for (final m in (r['metrics'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        final name = _healthNames[m['type']];
        if (name == null) continue;
        put(date, name, m['value']);
        if (name == 'hrv') {
          // The personal baseline range, for "is tonight unusual?"
          put(date, 'hrv_baseline_low', m['baselineLowerLimit']);
          put(date, 'hrv_baseline_high', m['baselineUpperLimit']);
        }
      }
    }

    final workouts = <HealthWorkout>[];
    for (final a in records['activities'] ?? const <Map<String, dynamic>>[]) {
      final start = _time(a['startTimeLocal']);
      final duration = _number(a['duration']);
      if (start == null || duration == null || duration == 0) continue;
      final distance = _number(a['distance']);
      final calories = _number(a['calories']);
      workouts.add(HealthWorkout(
        start: DateTime(start.year, start.month, start.day, start.hour, start.minute),
        type: a['activityType'] as String? ?? 'other',
        durationMin: _round(duration / 60000, 1), // milliseconds
        distanceKm: distance == null || distance == 0 ? null : _round(distance / 100000, 2), // centimetres
        // The export's activity calories are kilojoules.
        kcal: calories == null || calories == 0 ? null : (calories / 4.184).roundToDouble(),
        avgHr: _number(a['avgHr']),
        maxHr: _number(a['maxHr']),
        source: source,
      ));
    }

    return GarminImport(
      [
        for (final MapEntry(key: (date, metric), :value) in metrics.entries)
          HealthMetric(date: date, metric: metric, value: value, source: source),
      ],
      workouts,
    );
  }

  /// Garmin uses -1 and -2 (and sometimes 0) for "not measured".
  static double? _number(Object? value) => value is num && value >= 0 ? value.toDouble() : null;

  /// Local times are epoch milliseconds or ISO strings, without a zone.
  static DateTime? _time(Object? value) => switch (value) {
        num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true),
        String s => DateTime.tryParse(s.split('.').first),
        _ => null,
      };

  static double _round(double v, int places) => double.parse(v.toStringAsFixed(places));
}
