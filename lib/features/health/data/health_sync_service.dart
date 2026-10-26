import 'dart:io';

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
  const HealthSample.sleep(this.from, this.to)
      : kind = 'sleep',
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

  // Android records sleep as sessions; HealthKit as time asleep.
  static HealthDataType get _sleep => Platform.isAndroid ? HealthDataType.SLEEP_SESSION : HealthDataType.SLEEP_ASLEEP;
  static List<HealthDataType> get _types =>
      [HealthDataType.STEPS, _sleep, HealthDataType.RESTING_HEART_RATE, HealthDataType.WORKOUT];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  String get source => Platform.isAndroid ? HealthSource.healthConnect : HealthSource.healthKit;

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
    if (granted && Platform.isAndroid && !await _health.isHealthDataHistoryAuthorized()) {
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
      types: [_sleep, HealthDataType.RESTING_HEART_RATE, HealthDataType.WORKOUT],
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
    try {
      if (!await isEnabled()) return;
      await sync();
    } catch (e) {
      debugPrint('Health sync failed: $e');
    }
  }

  /// Reads from a day before the last sync (late data arrives) or
  /// [firstSyncDays] back, to now. Returns how many days had data.
  Future<int> sync({DateTime? now}) async {
    final end = now ?? DateTime.now();
    final last = await lastSync();
    final from = dayOf(last == null
        ? DateTime(end.year, end.month, end.day - firstSyncDays)
        : DateTime(last.year, last.month, last.day - 1));

    final steps = <DateTime, int>{};
    for (var d = from; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
      final n = await _store.steps(d, DateTime(d.year, d.month, d.day + 1));
      if (n != null && n > 0) steps[d] = n;
    }
    final samples = await _store.samples(from, end);
    final metrics = dailyMetrics(steps, samples, _store.source);
    final repo = HealthRepository(_db);
    await repo.saveMetrics(metrics);
    await repo.saveWorkouts(workouts(samples, _store.source));
    await (await SharedPreferences.getInstance()).setString(_lastSyncKey, end.toIso8601String());
    return {for (final m in metrics) m.date}.length;
  }

  /// Imports a Garmin "Export Your Data" zip. Returns days and workouts read.
  Future<(int, int)> importGarmin(List<int> zip) async {
    final export = GarminExportReader.readZip(zip);
    final repo = HealthRepository(_db);
    await repo.saveMetrics(export.metrics);
    await repo.saveWorkouts(export.workouts);
    return (export.days, export.workouts.length);
  }

  /// Steps per day, minutes asleep per night (on the day it ended, like the
  /// app's sleep) and the day's average resting heart rate.
  static List<HealthMetric> dailyMetrics(Map<DateTime, int> steps, List<HealthSample> samples, String source) {
    final sleep = <DateTime, double>{};
    final heart = <DateTime, List<double>>{};
    for (final s in samples) {
      switch (s.kind) {
        case 'sleep':
          final day = dayOf(s.to);
          sleep[day] = (sleep[day] ?? 0) + s.to.difference(s.from).inSeconds / 60;
        case 'resting_hr':
          (heart[dayOf(s.from)] ??= []).add(s.value);
      }
    }
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
              start: DateTime(s.from.year, s.from.month, s.from.day, s.from.hour, s.from.minute),
              type: s.workoutType ?? 'other',
              durationMin: (s.to.difference(s.from).inSeconds / 6).round() / 10,
              distanceKm: s.distanceKm == null ? null : (s.distanceKm! * 100).round() / 100,
              kcal: s.kcal,
              source: source,
            ),
      ];
}
