import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/database/database_service.dart';
import '../../../shared/services/database/repositories/health_repository.dart';
import '../../../shared/utils/date_utils.dart';
import 'garmin_export_reader.dart';
import 'models/health_metric.dart';

/// One reading from the phone's health store, reduced to what the app keeps.
class HealthSample {
  /// Time asleep (any stage).
  const HealthSample.sleep(this.from, this.to)
      : kind = 'sleep',
        value = 0,
        workoutType = null,
        kcal = null,
        distanceKm = null;

  /// A whole sleep session, awake time included; used only for nights
  /// without stages.
  const HealthSample.sleepSession(this.from, this.to)
      : kind = 'sleep_session',
        value = 0,
        workoutType = null,
        kcal = null,
        distanceKm = null;

  const HealthSample.restingHr(this.from, this.value)
      : kind = 'resting_hr',
        to = from,
        workoutType = null,
        kcal = null,
        distanceKm = null;

  const HealthSample.workout(this.from, this.to, {required String type, this.kcal, this.distanceKm})
      : kind = 'workout',
        value = 0,
        workoutType = type;

  final String kind;
  final DateTime from;
  final DateTime to;
  final double value;
  final String? workoutType;
  final double? kcal;
  final double? distanceKm;
}

/// The phone's health store: Health Connect on Android, HealthKit on iOS.
abstract class HealthStore {
  /// [HealthSource.healthConnect] or [HealthSource.healthKit].
  String get source;

  /// Whether the store can be used (Health Connect may need installing).
  Future<bool> available();

  /// Asks for read access; true when granted.
  Future<bool> requestAccess();

  /// Steps from [from] to [to], de-duplicated across apps by the store.
  Future<int?> steps(DateTime from, DateTime to);

  Future<List<HealthSample>> samples(DateTime from, DateTime to);
}

/// [HealthStore] through the `health` plugin.
class PluginHealthStore implements HealthStore {
  final _health = Health();
  var _configured = false;

  static bool get _android => defaultTargetPlatform == TargetPlatform.android;

  // Watches record sleep as stages (light, deep, REM); some apps only as
  // "asleep" or, on Android, a session.
  static List<HealthDataType> get _sleepTypes => [
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        if (_android) HealthDataType.SLEEP_SESSION,
      ];
  static List<HealthDataType> get _types =>
      [HealthDataType.STEPS, ..._sleepTypes, HealthDataType.RESTING_HEART_RATE, HealthDataType.WORKOUT];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  String get source => _android ? HealthSource.healthConnect : HealthSource.healthKit;

  @override
  Future<bool> available() async {
    await _configure();
    if (await _health.isHealthConnectAvailable()) return true;
    await _health.installHealthConnect();
    return false;
  }

  @override
  Future<bool> requestAccess() async {
    await _configure();
    final types = _types;
    final granted = await _health.requestAuthorization(types, permissions: [for (final _ in types) HealthDataAccess.READ]);
    // Health Connect only reads 30 days back unless history is allowed too.
    if (granted && _android && !await _health.isHealthDataHistoryAuthorized()) {
      await _health.requestHealthDataHistoryAuthorization();
    }
    return granted;
  }

  @override
  Future<int?> steps(DateTime from, DateTime to) async {
    await _configure();
    return _health.getTotalStepsInInterval(from, to);
  }

  @override
  Future<List<HealthSample>> samples(DateTime from, DateTime to) async {
    await _configure();
    final points = await _health.getHealthDataFromTypes(
      types: [..._sleepTypes, HealthDataType.RESTING_HEART_RATE, HealthDataType.WORKOUT],
      startTime: from,
      endTime: to,
    );
    return [
      for (final p in points)
        switch (p.value) {
          WorkoutHealthValue w => HealthSample.workout(
              p.dateFrom,
              p.dateTo,
              type: w.workoutActivityType.name.toLowerCase(),
              kcal: w.totalEnergyBurned?.toDouble(),
              distanceKm: w.totalDistance == null ? null : w.totalDistance! / 1000,
            ),
          NumericHealthValue v when p.type == HealthDataType.RESTING_HEART_RATE => HealthSample.restingHr(p.dateFrom, v.numericValue.toDouble()),
          _ when p.type == HealthDataType.SLEEP_SESSION => HealthSample.sleepSession(p.dateFrom, p.dateTo),
          _ => HealthSample.sleep(p.dateFrom, p.dateTo),
        },
    ];
  }
}

/// Reads health data into the app: Health Connect / HealthKit sync, turned
/// on in Settings, and Garmin export imports. Re-running either replaces
/// the same days' values, so it never duplicates. Days with a Garmin export
/// value keep it, as the garmin export is preferred where both exist.
class HealthSyncService {
  HealthSyncService(this._db, [HealthStore? store]) : _store = store ?? PluginHealthStore();

  final DatabaseService _db;
  final HealthStore _store;

  static const _enabledKey = 'health_sync_enabled';
  static const _lastSyncKey = 'health_last_sync';

  /// How far back the first sync reads.
  static const firstSyncDays = 90;

  /// Health Connect and HealthKit exist only on phones.
  static bool get isSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// The sync running now, so a launch sync and a tap share one run.
  static Future<int>? _running;

  static Future<bool> isEnabled() async => (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  static Future<DateTime?> lastSync() async {
    final iso = (await SharedPreferences.getInstance()).getString(_lastSyncKey);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  /// Turns sync on (asking for access, only now) or off. Returns whether
  /// sync is on afterwards, with a reason when it couldn't be turned on.
  Future<(bool, String?)> setEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    if (!on) {
      await prefs.setBool(_enabledKey, false);
      return (false, null);
    }
    if (!await _store.available()) return (false, 'Install Health Connect, then try again.');
    if (!await _store.requestAccess()) return (false, 'Access wasn’t granted.');
    await prefs.setBool(_enabledKey, true);
    return (true, null);
  }

  /// Syncs when turned on; quietly does nothing otherwise or on failure.
  Future<void> syncIfEnabled() async {
    if (!isSupported) return;
    try {
      if (!await isEnabled()) return;
      await sync();
    } catch (e) {
      debugPrint('Health sync failed: $e');
    }
  }

  /// Re-reads whole days from the day before the last sync (late data
  /// arrives), or [firstSyncDays] back, to now, and replaces what this
  /// store gave for those days. Returns how many days had data.
  Future<int> sync({DateTime? now}) => _running ??= _sync(now ?? DateTime.now()).whenComplete(() => _running = null);

  Future<int> _sync(DateTime end) async {
    final last = await lastSync();
    final first = dayOf(last == null
        ? DateTime(end.year, end.month, end.day - firstSyncDays)
        : DateTime(last.year, last.month, last.day - 1));
    // From noon the day before, so the first day's night is read whole.
    final readFrom = DateTime(first.year, first.month, first.day - 1, 12);

    final days = [for (var d = first; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) d];
    final steps = <DateTime, int>{};
    // A week at a time: quicker than one by one, gentle on rate limits.
    for (var i = 0; i < days.length; i += 7) {
      final batch = days.skip(i).take(7);
      final counts = await Future.wait([for (final d in batch) _store.steps(d, DateTime(d.year, d.month, d.day + 1))]);
      for (final (d, n) in [for (final (j, d) in batch.indexed) (d, counts[j])]) {
        if (n != null && n > 0) steps[d] = n;
      }
    }
    final samples = await _store.samples(readFrom, end);
    final metrics = [for (final m in dailyMetrics(steps, samples, _store.source)) if (!m.date.isBefore(first)) m];
    final sessions = [for (final w in workouts(samples, _store.source)) if (!w.start.isBefore(first)) w];
    await HealthRepository(_db).replaceRange(_store.source, first, end, metrics, sessions);
    await (await SharedPreferences.getInstance()).setString(_lastSyncKey, end.toIso8601String());
    return {for (final m in metrics) m.date}.length;
  }

  /// Imports a Garmin "Export Your Data" zip from [path]. Returns days
  /// and workouts read.
  Future<(int, int)> importGarmin(String path) async {
    final export = await GarminExportReader.readZipFile(path);
    final repo = HealthRepository(_db);
    await repo.saveMetrics(export.metrics);
    await repo.saveWorkouts(export.workouts);
    return (export.days, export.workouts.length);
  }

  /// The night a stretch of sleep belongs to: the day it ended, like the
  /// app's sleep, except that sleep ending after 18:00 counts towards the
  /// next morning.
  static DateTime nightOf(DateTime end) => dayOf(end.add(const Duration(hours: 6)));

  /// Minutes covered by [spans], counting overlaps once (several apps can
  /// record the same night).
  static double _minutesCovered(List<(DateTime, DateTime)> spans) {
    final sorted = [...spans]..sort((a, b) => a.$1.compareTo(b.$1));
    var total = 0.0;
    DateTime? start, end;
    for (final (from, to) in sorted) {
      if (end != null && !from.isAfter(end)) {
        if (to.isAfter(end)) end = to;
        continue;
      }
      if (start != null) total += end!.difference(start).inSeconds / 60;
      (start, end) = (from, to);
    }
    if (start != null) total += end!.difference(start).inSeconds / 60;
    return total;
  }

  /// Steps per day, minutes asleep per night (stages where recorded, else
  /// sessions; overlaps counted once) and the day's average resting heart
  /// rate.
  static List<HealthMetric> dailyMetrics(Map<DateTime, int> steps, List<HealthSample> samples, String source) {
    final asleep = <DateTime, List<(DateTime, DateTime)>>{};
    final sessions = <DateTime, List<(DateTime, DateTime)>>{};
    final heart = <DateTime, List<double>>{};
    for (final s in samples) {
      switch (s.kind) {
        case 'sleep':
          (asleep[nightOf(s.to)] ??= []).add((s.from, s.to));
        case 'sleep_session':
          (sessions[nightOf(s.to)] ??= []).add((s.from, s.to));
        case 'resting_hr':
          (heart[dayOf(s.from)] ??= []).add(s.value);
      }
    }
    final sleep = {
      for (final night in {...asleep.keys, ...sessions.keys}) night: _minutesCovered(asleep[night] ?? sessions[night]!),
    };
    return [
      for (final MapEntry(:key, :value) in steps.entries)
        HealthMetric(date: dayOf(key), metric: 'steps', value: value.toDouble(), source: source),
      for (final MapEntry(:key, :value) in sleep.entries)
        if (value > 0) HealthMetric(date: key, metric: 'sleep_minutes', value: value.roundToDouble(), source: source),
      for (final MapEntry(:key, :value) in heart.entries)
        HealthMetric(date: key, metric: 'resting_hr', value: (value.reduce((a, b) => a + b) / value.length).roundToDouble(), source: source),
    ];
  }

  static List<HealthWorkout> workouts(List<HealthSample> samples, String source) => [
        for (final s in samples)
          if (s.kind == 'workout')
            HealthWorkout(
              // To the second: two apps' workouts can start in the same minute.
              start: DateTime(s.from.year, s.from.month, s.from.day, s.from.hour, s.from.minute, s.from.second),
              type: s.workoutType ?? 'other',
              durationMin: (s.to.difference(s.from).inSeconds / 6).round() / 10,
              distanceKm: s.distanceKm == null ? null : (s.distanceKm! * 100).round() / 100,
              kcal: s.kcal,
              source: source,
            ),
      ];
}
