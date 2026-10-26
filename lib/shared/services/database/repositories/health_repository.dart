import 'package:sqflite/sqflite.dart';

import '../../../../features/health/data/models/health_metric.dart';
import '../../../utils/date_utils.dart';
import '../database_service.dart';

/// Daily health metrics and workouts from Garmin, Health Connect,
/// HealthKit or manual entry.
class HealthRepository {
  HealthRepository([DatabaseService? db]) : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  /// Inserts or replaces values (one per date, metric and source).
  Future<void> saveMetrics(List<HealthMetric> metrics) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final m in metrics) {
      final map = m.toMap()..['date'] = dayOf(m.date).toIso8601String();
      batch.insert('health_metrics', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Every metric on [day], one value each, from the most preferred source.
  Future<Map<String, HealthMetric>> forDay(DateTime day) async {
    final db = await _db.database;
    final rows = await db.query('health_metrics', where: 'date = ?', whereArgs: [dayOf(day).toIso8601String()]);
    final best = <String, HealthMetric>{};
    for (final metric in rows.map(HealthMetric.fromMap)) {
      final current = best[metric.metric];
      if (current == null || HealthSource.rank(metric.source) < HealthSource.rank(current.source)) {
        best[metric.metric] = metric;
      }
    }
    return best;
  }

  /// One value of [metric] per day from [start] to [end], preferred source.
  Future<List<HealthMetric>> series(String metric, DateTime start, DateTime end) async {
    final db = await _db.database;
    final to = dayOf(end);
    final rows = await db.query(
      'health_metrics',
      where: 'metric = ? AND date >= ? AND date < ?',
      whereArgs: [metric, dayOf(start).toIso8601String(), DateTime(to.year, to.month, to.day + 1).toIso8601String()],
      orderBy: 'date ASC',
    );
    final byDay = <String, HealthMetric>{};
    for (final m in rows.map(HealthMetric.fromMap)) {
      final key = m.date.toIso8601String();
      final current = byDay[key];
      if (current == null || HealthSource.rank(m.source) < HealthSource.rank(current.source)) {
        byDay[key] = m;
      }
    }
    return byDay.values.toList();
  }

  /// Inserts or replaces workouts (unique on start time and source).
  Future<void> saveWorkouts(List<HealthWorkout> workouts) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final w in workouts) {
      final map = w.toMap()..remove('id');
      batch.insert('health_workouts', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Replaces everything [source] recorded from day [from] to day [to]
  /// with [metrics] and [workouts], so values deleted or corrected at the
  /// source go away here too.
  Future<void> replaceRange(String source, DateTime from, DateTime to, List<HealthMetric> metrics, List<HealthWorkout> workouts) async {
    final db = await _db.database;
    final start = dayOf(from).toIso8601String();
    final last = dayOf(to);
    final end = DateTime(last.year, last.month, last.day + 1).toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('health_metrics', where: 'source = ? AND date >= ? AND date < ?', whereArgs: [source, start, end]);
      await txn.delete('health_workouts', where: 'source = ? AND start >= ? AND start < ?', whereArgs: [source, start, end]);
      for (final m in metrics) {
        await txn.insert('health_metrics', m.toMap()..['date'] = dayOf(m.date).toIso8601String(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final w in workouts) {
        await txn.insert('health_workouts', w.toMap()..remove('id'), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<HealthWorkout>> workoutsInRange(DateTime start, DateTime end) async {
    final db = await _db.database;
    final to = dayOf(end);
    final rows = await db.query(
      'health_workouts',
      where: 'start >= ? AND start < ?',
      whereArgs: [dayOf(start).toIso8601String(), DateTime(to.year, to.month, to.day + 1).toIso8601String()],
      orderBy: 'start ASC',
    );
    return rows.map(HealthWorkout.fromMap).toList();
  }
}
