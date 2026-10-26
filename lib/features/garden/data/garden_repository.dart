import '../../../shared/services/database/database_service.dart';
import '../../../shared/utils/date_utils.dart';
import '../../health/data/models/health_metric.dart';
import '../domain/garden_day.dart';
import '../domain/plant.dart';

/// Builds garden days from every table, one query per table for a range.
class GardenRepository {
  GardenRepository([DatabaseService? db]) : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  /// How far back tags are counted to tell routine from distinctive.
  static const routineWindow = Duration(days: 56);

  /// One [GardenDay] for each day from [start] to [end] inclusive.
  Future<List<GardenDay>> daysInRange(DateTime start, DateTime end) async {
    final logs = await logsInRange(start, end);
    return [for (final log in logs) GardenDay.from(log)];
  }

  Future<List<DayLog>> logsInRange(DateTime start, DateTime end) async {
    final db = await _db.database;
    final from = dayOf(start);
    final last = dayOf(end);
    final to = DateTime(last.year, last.month, last.day + 1);
    final args = [from.toIso8601String(), to.toIso8601String()];
    const inRange = 'date >= ? AND date < ?';

    DateTime day(Object? iso) => dayOf(DateTime.parse(iso as String));

    // Tags from the routine window before the range too, to tell what is
    // routine from what stands out.
    final windowStart = dayOf(from.subtract(routineWindow));
    final tags = <DateTime, List<String>>{};
    for (final r in await db.rawQuery(
      'SELECT a.date, t.name FROM activity_entries a JOIN tags t ON t.id = a.tagId WHERE a.$inRange',
      [windowStart.toIso8601String(), to.toIso8601String()],
    )) {
      tags.putIfAbsent(day(r['date']), () => []).add(r['name'] as String);
    }
    // One baseline for the whole range, from the weeks before it, keeps a
    // month consistent.
    final routine = GardenDay.routineTagsFor([
      for (final MapEntry(key: date, value: names) in tags.entries)
        if (date.isBefore(from)) names,
    ]);

    final exercises = {
      for (final r in await db.rawQuery(
        'SELECT date, COUNT(DISTINCT lower(COALESCE(exerciseName, type))) AS n FROM exercise_entries WHERE $inRange GROUP BY date',
        args,
      ))
        day(r['date']): r['n'] as int,
    };
    final meals = {
      for (final r in await db.rawQuery('SELECT date, COUNT(*) AS n FROM meal_entries WHERE $inRange GROUP BY date', args))
        day(r['date']): r['n'] as int,
    };
    final sleep = <DateTime, double>{};
    for (final r in await db.query('sleep_entries', columns: ['date', 'totalHours'], where: inRange, whereArgs: args)) {
      final hours = (r['totalHours'] as num?)?.toDouble();
      if (hours != null) sleep[day(r['date'])] = hours;
    }
    final moods = {
      for (final r in await db.query('mood_entries', columns: ['date', 'moodLevel'], where: inRange, whereArgs: args))
        day(r['date']): r['moodLevel'] as int,
    };
    final momentMoods = <DateTime, List<int>>{};
    final momentCounts = <DateTime, int>{};
    for (final r in await db.query('journal_entries', columns: ['date', 'mood'], where: inRange, whereArgs: args)) {
      final d = day(r['date']);
      momentCounts[d] = (momentCounts[d] ?? 0) + 1;
      if (r['mood'] != null) momentMoods.putIfAbsent(d, () => []).add(r['mood'] as int);
    }
    final checkins = {
      for (final r in await db.query('day_checkins', columns: ['date', 'plant_override'], where: inRange, whereArgs: args))
        day(r['date']): r['plant_override'] as String?,
    };

    // Watch data: one value per day from the preferred source.
    final metrics = <(DateTime, String), (double, String)>{};
    for (final r in await db.query(
      'health_metrics',
      where: "$inRange AND metric IN ('steps', 'sleep_minutes')",
      whereArgs: args,
    )) {
      final key = (day(r['date']), r['metric'] as String);
      final source = r['source'] as String;
      final current = metrics[key];
      if (current == null || HealthSource.rank(source) < HealthSource.rank(current.$2)) {
        metrics[key] = ((r['value'] as num).toDouble(), source);
      }
    }
    final workouts = <DateTime, int>{};
    for (final r in await db.query('health_workouts', columns: ['start'], where: 'start >= ? AND start < ?', whereArgs: args)) {
      final d = day(r['start']);
      workouts[d] = (workouts[d] ?? 0) + 1;
    }

    return [
      for (var d = from; d.isBefore(to); d = DateTime(d.year, d.month, d.day + 1))
        DayLog(
          date: d,
          tagNames: tags[d] ?? const [],
          exerciseKinds: exercises[d] ?? 0,
          workouts: workouts[d] ?? 0,
          steps: metrics[(d, 'steps')]?.$1,
          // The app's own sleep log first; the watch fills days without one.
          sleepHours: sleep[d] ?? _hours(metrics[(d, 'sleep_minutes')]?.$1),
          dayMood: moods[d],
          momentMoods: momentMoods[d] ?? const [],
          momentCount: momentCounts[d] ?? 0,
          mealCount: meals[d] ?? 0,
          hasCheckin: checkins.containsKey(d),
          plantOverride: PlantSpecies.byName(checkins[d]),
          routineTags: routine,
        ),
    ];
  }

  static double? _hours(double? minutes) => minutes == null ? null : minutes / 60;
}
