import '../../../shared/services/database/database_service.dart';
import '../../../shared/utils/date_utils.dart';
import '../../health/data/models/health_metric.dart';
import '../../exercise/domain/effort.dart';
import '../../meals/domain/diet_score.dart';
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
    final firstMonth = DateTime(from.year, from.month);
    final windowStart = DateTime(firstMonth.year, firstMonth.month, firstMonth.day - routineWindow.inDays);
    final tags = <DateTime, List<String>>{};
    for (final r in await db.rawQuery(
      'SELECT a.date, t.name FROM activity_entries a JOIN tags t ON t.id = a.tagId WHERE a.$inRange',
      [windowStart.toIso8601String(), to.toIso8601String()],
    )) {
      tags.putIfAbsent(day(r['date']), () => []).add(r['name'] as String);
    }
    // One baseline per month, from the weeks before the 1st, so a day gets
    // the same plant on Today as in its month, and a month is consistent.
    final routineByMonth = <DateTime, Set<String>>{};
    Set<String> routineFor(DateTime d) => routineByMonth.putIfAbsent(DateTime(d.year, d.month), () {
          final month = DateTime(d.year, d.month);
          final start = DateTime(month.year, month.month, month.day - routineWindow.inDays);
          return GardenDay.routineTagsFor([
            for (final MapEntry(key: date, value: names) in tags.entries)
              if (!date.isBefore(start) && date.isBefore(month)) names,
          ]);
        });

    final exercises = {
      for (final r in await db.rawQuery(
        // Runs are one kind whatever they're named.
        "SELECT date, COUNT(DISTINCT CASE WHEN type LIKE '%run%' THEN 'run' ELSE lower(COALESCE(exerciseName, type)) END) AS n "
        'FROM exercise_entries WHERE $inRange GROUP BY date',
        args,
      ))
        day(r['date']): r['n'] as int,
    };
    // How hard each day's exercise was, from what was logged.
    final logged = <DateTime, double>{};
    for (final r in await db.query(
      'exercise_entries',
      columns: ['date', 'type', 'exerciseName', 'reps', 'sets', 'distance', 'duration', 'notes'],
      where: inRange,
      whereArgs: args,
    )) {
      final points = Effort.entryPoints(
        run: (r['type'] as String).endsWith('run'),
        name: r['exerciseName'] as String?,
        reps: r['reps'] as int?,
        sets: r['sets'] as int?,
        km: (r['distance'] as num?)?.toDouble(),
        notes: r['notes'] as String?,
        duration: r['duration'] == null ? null : Duration(seconds: r['duration'] as int),
      );
      logged[day(r['date'])] = (logged[day(r['date'])] ?? 0) + points;
    }
    // How healthy each day's food was, from the meals' names and calories.
    final eaten = <DateTime, List<(String, double?)>>{};
    for (final r in await db.rawQuery(
      'SELECT m.date, m.name, m.calories, m.quantity, f.kcal FROM meal_entries m '
      'LEFT JOIN food_items f ON f.id = m.food_item_id WHERE m.$inRange',
      args,
    )) {
      final kcal = (r['calories'] as num?)?.toDouble() ?? switch ((r['kcal'] as num?)?.toDouble()) {
        final k? => k * ((r['quantity'] as num?) ?? 1),
        null => null,
      };
      (eaten[day(r['date'])] ??= []).add((r['name'] as String, kcal));
    }
    final meals = {
      for (final r in await db.rawQuery('SELECT date, COUNT(*) AS n FROM meal_entries WHERE $inRange GROUP BY date', args))
        day(r['date']): r['n'] as int,
    };
    final sleep = <DateTime, double>{};
    final sleepLogged = <DateTime>{};
    for (final r in await db.query('sleep_entries', columns: ['date', 'totalHours'], where: inRange, whereArgs: args)) {
      sleepLogged.add(day(r['date']));
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
      where: "$inRange AND metric IN ('steps', 'sleep_minutes', 'intensity_minutes')",
      whereArgs: args,
    )) {
      final key = (day(r['date']), r['metric'] as String);
      final source = r['source'] as String;
      final current = metrics[key];
      if (current == null || HealthSource.rank(source) < HealthSource.rank(current.$2)) {
        metrics[key] = ((r['value'] as num).toDouble(), source);
      }
    }
    // Workouts from one source per day, the preferred one, so a run in
    // both a Garmin export and Health Connect counts once.
    final bySource = <DateTime, Map<String, int>>{};
    for (final r in await db.query('health_workouts', columns: ['start', 'source'], where: 'start >= ? AND start < ?', whereArgs: args)) {
      final counts = bySource[day(r['start'])] ??= {};
      counts[r['source'] as String] = (counts[r['source'] as String] ?? 0) + 1;
    }
    final workouts = {
      for (final MapEntry(key: d, value: counts) in bySource.entries)
        d: counts[(counts.keys.toList()..sort((a, b) => HealthSource.rank(a).compareTo(HealthSource.rank(b)))).first]!,
    };

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
          sleepLogged: sleepLogged.contains(d),
          dayMood: moods[d],
          momentMoods: momentMoods[d] ?? const [],
          momentCount: momentCounts[d] ?? 0,
          mealCount: meals[d] ?? 0,
          hasCheckin: checkins.containsKey(d),
          plantOverride: PlantSpecies.byName(checkins[d]),
          diet: eaten[d] == null ? null : DietScore.forDay(eaten[d]!),
          effort: Effort.levelFor(Effort.dayPoints(
            logged[d] ?? 0,
            intensityMinutes: metrics[(d, 'intensity_minutes')]?.$1,
            watchWorkout: (workouts[d] ?? 0) > 0,
          )),
          routineTags: routineFor(d),
        ),
    ];
  }

  static double? _hours(double? minutes) => minutes == null ? null : minutes / 60;
}
