import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../shared/services/database/database_service.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../exercise/data/models/exercise_entry.dart';
import '../../../exercise/domain/effort.dart';
import '../../../garden/data/garden_repository.dart';
import '../../../garden/domain/plant.dart';
import '../../../../shared/services/database/repositories/health_repository.dart';
import '../models/metric_data.dart';

/// What a fun fact is about, for its icon and colour.
enum FactKind { food, newFood, spend, events, exercise, distance, sleep, logging, weekday, garden, memory }

/// One light-hearted observation about a period: a headline value and a
/// line of detail. Facts state what was logged; they never give advice.
class FunFact {
  const FunFact({required this.kind, required this.title, required this.value, required this.detail, this.details});

  final FactKind kind;
  final String title;
  final String value;
  final String detail;

  /// Everything behind the fact, loaded when its card is tapped.
  final Future<FactDetail> Function()? details;

  @override
  String toString() => '$title: $value ($detail)';
}

/// One line in a fact's full list: a food and how often, a meal and its
/// price, a night and its length.
class FactRow {
  const FactRow({required this.label, this.sub, this.date, this.value, this.valueText, this.group});

  final String label;
  final String? sub;

  /// The day it happened, when it was one day; tapping opens that day.
  final DateTime? date;

  /// What "Biggest" and "Smallest" sort by.
  final num? value;
  final String? valueText;

  /// A heading the row sits under (a weekday), in the order rows give.
  final String? group;
}

/// The list behind a fact, sorted biggest first unless [byDate].
class FactDetail {
  const FactDetail({required this.title, required this.rows, this.byDate = false, this.note});

  final String title;
  final List<FactRow> rows;

  /// Opens sorted newest first (a list of days) rather than biggest first.
  final bool byDate;

  /// A line above the list saying what it holds.
  final String? note;
}

/// Distances from around the world for picturing kilometres, each phrased
/// to read after "about", "about 3 times" and "about 40% of".
const distanceLandmarks = [
  (2.7, 'the Golden Gate Bridge'),
  (8.849, 'the height of Mount Everest'),
  (9.8, 'a lap of Central Park'),
  (10.9, 'the depth of the Mariana Trench'),
  (21.6, 'the length of Manhattan'),
  (33.0, 'the width of the English Channel'),
  (42.195, 'a marathon'),
  (82.0, 'the length of the Panama Canal'),
  (100.0, 'the distance to the edge of space'),
  (117.0, "the length of Hadrian's Wall"),
  (344.0, 'the distance from London to Paris'),
  (400.0, 'the distance up to the Space Station'),
  (446.0, 'the length of the Grand Canyon'),
  (780.0, 'the Camino de Santiago'),
  (2300.0, 'the length of the Great Barrier Reef'),
  (3400.0, 'a Tour de France'),
  (3500.0, 'the Appalachian Trail'),
  (3940.0, 'Route 66'),
  (6650.0, 'the length of the Nile'),
  (21196.0, 'the Great Wall of China'),
  (40075.0, 'a lap around the Earth'),
];

/// "about 2.4 times a marathon", "about the length of Manhattan". [seed]
/// picks among the landmarks that fit (0.9 to 15 times), so different
/// periods compare with different things; the same seed, the same one.
String distanceComparison(double km, {int seed = 0}) {
  final fitting = [for (final l in distanceLandmarks) if (km >= l.$1 * 0.9 && km <= l.$1 * 15) l];
  // Nothing fits (a very long way): the largest, as a share or a multiple.
  final best = fitting.isEmpty ? distanceLandmarks.last : fitting[seed.abs() % fitting.length];
  final times = km / best.$1;
  if (times < 0.8) return 'about ${(times * 100).round()}% of ${best.$2}';
  if (times < 1.25) return 'about ${best.$2}';
  final rounded = times.toStringAsFixed(times < 10 ? 1 : 0).replaceFirst(RegExp(r'\.0$'), '');
  return 'about $rounded times ${best.$2}';
}

/// Light-hearted facts about a period, from every table. Each fact needs
/// enough data behind it, so quiet periods show fewer facts.
class FunFactsService {
  FunFactsService(this._db);

  final DatabaseService _db;

  static final _day = DateFormat('d MMM');
  static final _money = NumberFormat('#,##0.00');
  static final _count = NumberFormat('#,##0');

  /// [weightKg] is the profile's, for calories burned.
  Future<List<FunFact>> factsFor(DateRange range, {DateTime? today, double? weightKg}) async {
    final db = await _db.database;
    // All time starts at the first entry, not an arbitrary early date.
    final first = range.isAllTime ? await _db.firstLoggedDay() : null;
    final from = dayOf(first ?? range.start);
    final last = dayOf(range.end);
    final to = DateTime(last.year, last.month, last.day + 1);
    final args = [from.toIso8601String(), to.toIso8601String()];
    const inRange = 'date >= ? AND date < ?';
    final facts = <FunFact>[];

    // Go-to food.
    final top = await db.rawQuery('''
      SELECT COALESCE(f.name, m.name) AS name, COUNT(*) AS n FROM meal_entries m
      LEFT JOIN food_items f ON f.id = m.food_item_id
      WHERE m.$inRange GROUP BY lower(COALESCE(f.name, m.name)) ORDER BY n DESC LIMIT 1
    ''', args);
    if (top.isNotEmpty && (top.first['n'] as int) >= 3) {
      facts.add(FunFact(
        kind: FactKind.food,
        title: 'Go-to food',
        details: () async => FactDetail(
          title: 'Foods eaten',
          rows: [
            for (final r in await db.rawQuery('''
              SELECT COALESCE(f.name, m.name) AS name, COUNT(*) AS n, MAX(m.date) AS last FROM meal_entries m
              LEFT JOIN food_items f ON f.id = m.food_item_id
              WHERE m.$inRange GROUP BY lower(COALESCE(f.name, m.name))
            ''', args))
              FactRow(
                label: r['name'] as String,
                sub: 'Last on ${_day.format(DateTime.parse(r['last'] as String))}',
                value: r['n'] as int,
                valueText: '${r['n']}×',
              ),
          ],
        ),
        value: top.first['name'] as String,
        detail: '${top.first['n']} times',
      ));
    }

    // Foods eaten for the first time ever.
    final firsts = await db.rawQuery('''
      SELECT f.name FROM food_items f
      JOIN meal_entries m ON m.food_item_id = f.id
      GROUP BY f.id HAVING MIN(m.date) >= ? AND MIN(m.date) < ?
      ORDER BY MIN(m.date)
    ''', args);
    // Over all time every food is new, so it says nothing there.
    if (firsts.isNotEmpty && !range.isAllTime) {
      final names = firsts.map((r) => r['name'] as String).toList();
      facts.add(FunFact(
        kind: FactKind.newFood,
        title: 'New foods tried',
        details: () async => FactDetail(
          title: 'New foods tried',
          byDate: true,
          rows: [
            for (final r in await db.rawQuery('''
              SELECT f.name, MIN(m.date) AS first FROM food_items f
              JOIN meal_entries m ON m.food_item_id = f.id
              GROUP BY f.id HAVING MIN(m.date) >= ? AND MIN(m.date) < ?
            ''', args))
              FactRow(label: r['name'] as String, date: DateTime.parse(r['first'] as String)),
          ],
        ),
        value: '${names.length}',
        detail: names.length == 1 ? names.single : 'Including ${names.take(2).join(' and ')}',
      ));
    }

    // Spending and the priciest meal (SGD only, the default currency).
    final spend = await db.rawQuery('''
      SELECT SUM(price) AS total, COUNT(price) AS priced FROM meal_entries
      WHERE $inRange AND price IS NOT NULL AND currency = 'SGD'
    ''', args);
    // Per item: a line of six orders is buying for others, not a treat.
    final priciest = await db.rawQuery('''
      SELECT name, price * 1.0 / MAX(quantity, 1) AS price, date FROM meal_entries
      WHERE $inRange AND price IS NOT NULL AND currency = 'SGD' ORDER BY price * 1.0 / MAX(quantity, 1) DESC LIMIT 1
    ''', args);
    final priced = spend.first['priced'] as int;
    if (priced >= 5 && priciest.isNotEmpty) {
      final p = priciest.first;
      // Every priced meal, by its price per item.
      Future<List<FactRow>> pricedMeals() async => [
            for (final r in await db.rawQuery('''
              SELECT name, price * 1.0 / MAX(quantity, 1) AS each, quantity, date FROM meal_entries
              WHERE $inRange AND price IS NOT NULL AND currency = 'SGD'
            ''', args))
              FactRow(
                label: r['name'] as String,
                sub: (r['quantity'] as int) > 1 ? '${r['quantity']} of them' : null,
                date: DateTime.parse(r['date'] as String),
                value: r['each'] as num,
                valueText: '\$${_money.format(r['each'])}',
              ),
          ];
      facts.add(FunFact(
        kind: FactKind.spend,
        title: 'Biggest treat',
        value: '\$${_money.format(p['price'])}',
        detail: '${p['name']}, ${_day.format(DateTime.parse(p['date'] as String))}',
        details: () async => FactDetail(title: 'Meals by price', rows: await pricedMeals()),
      ));
      final total = spend.first['total'] as num;
      facts.add(FunFact(
        kind: FactKind.spend,
        title: 'Food spending',
        value: '\$${_money.format(total)}',
        detail: '$priced priced meals, \$${_money.format(total / priced)} each on average',
        details: () async => FactDetail(
          title: 'Spending by food',
          rows: [
            for (final r in await db.rawQuery('''
              SELECT COALESCE(f.name, m.name) AS name, SUM(m.price) AS total, COUNT(*) AS n FROM meal_entries m
              LEFT JOIN food_items f ON f.id = m.food_item_id
              WHERE m.$inRange AND m.price IS NOT NULL AND m.currency = 'SGD'
              GROUP BY lower(COALESCE(f.name, m.name))
            ''', args))
              FactRow(
                label: r['name'] as String,
                sub: '${r['n']} ${r['n'] == 1 ? 'time' : 'times'}',
                value: r['total'] as num,
                valueText: '\$${_money.format(r['total'])}',
              ),
          ],
        ),
      ));
    }

    // Events and gifts: kept apart from food spending.
    final events = (await db.rawQuery('''
      SELECT SUM(amount) AS total, COUNT(*) AS n FROM spending_entries
      WHERE $inRange AND currency = 'SGD' AND amount > 0
    ''', args)).first;
    if ((events['n'] as int) > 0) {
      final top = (await db.rawQuery('''
        SELECT label, date FROM spending_entries
        WHERE $inRange AND currency = 'SGD' AND amount > 0 ORDER BY amount DESC LIMIT 1
      ''', args)).first;
      facts.add(FunFact(
        kind: FactKind.events,
        title: 'Events & gifts',
        details: () async => FactDetail(
          title: 'Events & gifts',
          rows: [
            for (final r in await db.rawQuery('''
              SELECT label, amount, date FROM spending_entries WHERE $inRange AND currency = 'SGD' AND amount > 0
            ''', args))
              FactRow(
                label: r['label'] as String,
                date: DateTime.parse(r['date'] as String),
                value: r['amount'] as num,
                valueText: '\$${_money.format(r['amount'])}',
              ),
          ],
        ),
        value: '\$${_money.format(events['total'])}',
        detail: events['n'] == 1
            ? '${top['label']}, ${_day.format(DateTime.parse(top['date'] as String))}'
            : '${events['n']} of them. The biggest: ${top['label']}',
      ));
    }

    // Favourite exercise: the one done on the most days, with what all
    // exercise added up to (calories at the profile's weight).
    final byExercise = <String, ({String name, Set<DateTime> days, int reps, double kcal})>{};
    var allKcal = 0.0;
    for (final r in await db.rawQuery('''
      SELECT e.*, COALESCE(x.name, e.exerciseName) AS shown FROM exercise_entries e
      LEFT JOIN exercise_items x ON x.id = e.exercise_item_id WHERE e.$inRange
    ''', args)) {
      final x = ExerciseEntry.fromMap(r);
      final kcal = Effort.kcalBurned(
        run: x.type == ExerciseType.run,
        weightKg: weightKg ?? Effort.defaultWeightKg,
        name: x.exerciseName,
        reps: x.reps,
        sets: x.sets,
        km: x.distance,
        notes: x.notes,
        duration: x.duration,
      );
      allKcal += kcal;
      final name = (r['shown'] as String?) ?? (x.type == ExerciseType.run ? 'Run' : 'Weights');
      final key = name.toLowerCase();
      final was = byExercise[key];
      byExercise[key] = (
        name: was?.name ?? name,
        days: {...?was?.days, dayOf(x.date)},
        reps: (was?.reps ?? 0) + (x.reps ?? 0) * math.max(x.sets ?? 1, 1),
        kcal: (was?.kcal ?? 0) + kcal,
      );
    }
    final ranked = byExercise.values.toList()..sort((a, b) => b.days.length.compareTo(a.days.length));
    if (ranked.isNotEmpty && ranked.first.days.length >= 2) {
      final fav = ranked.first;
      final sessionDays = {for (final e in byExercise.values) ...e.days}.length;
      String reps(int n) => n > 0 ? ' · ${_count.format(n)} reps' : '';
      facts.add(FunFact(
        kind: FactKind.exercise,
        title: 'Favourite exercise',
        value: fav.name,
        detail: 'On ${fav.days.length} days${reps(fav.reps)}. ≈${_count.format(allKcal.round())} kcal burned in all',
        details: () async => FactDetail(
          title: 'Your exercise',
          note: '${byExercise.length} ${byExercise.length == 1 ? 'exercise' : 'exercises'} on $sessionDays '
              '${sessionDays == 1 ? 'day' : 'days'}, ≈${_count.format(allKcal.round())} kcal burned in all.',
          rows: [
            for (final e in ranked)
              FactRow(
                label: e.name,
                sub: 'On ${e.days.length} ${e.days.length == 1 ? 'day' : 'days'}${reps(e.reps)}',
                value: e.kcal,
                valueText: '≈${_count.format(e.kcal.round())} kcal',
              ),
          ],
        ),
      ));
    }

    // Distance on foot: watch steps (about 0.75 m a step) or logged runs.
    final stepDays = await HealthRepository(_db).series('steps', from, last);
    final steps = stepDays.isEmpty ? null : stepDays.fold<double>(0, (sum, m) => sum + m.value);
    final hasSteps = steps != null && steps > 0;
    final runs = (await db.rawQuery(
      "SELECT SUM(distance) AS km FROM exercise_entries WHERE $inRange AND type LIKE '%run%'",
      args,
    )).first['km'] as num?;
    final onFoot = hasSteps ? steps * 0.00075 : (runs ?? 0).toDouble();
    if (onFoot >= 10) {
      // Seeded by the period, so each period has its own comparison.
      final comparison = distanceComparison(onFoot, seed: from.difference(DateTime(2000)).inDays);
      facts.add(FunFact(
        kind: FactKind.distance,
        title: hasSteps ? 'Distance on foot' : 'Distance run',
        details: () async => FactDetail(
          title: hasSteps ? 'Distance on foot by day' : 'Runs',
          rows: hasSteps
              ? [
                  for (final m in stepDays)
                    FactRow(
                      label: DateFormat('EEE d MMM y').format(m.date),
                      sub: '${_count.format(m.value)} steps',
                      date: m.date,
                      value: m.value * 0.00075,
                      valueText: '${(m.value * 0.00075).toStringAsFixed(1)} km',
                    ),
                ]
              : [
                  for (final r in await db.rawQuery(
                    "SELECT date, distance FROM exercise_entries WHERE $inRange AND type LIKE '%run%' AND distance IS NOT NULL",
                    args,
                  ))
                    FactRow(
                      label: DateFormat('EEE d MMM y').format(DateTime.parse(r['date'] as String)),
                      date: DateTime.parse(r['date'] as String),
                      value: r['distance'] as num,
                      valueText: '${(r['distance'] as num).toStringAsFixed(1)} km',
                    ),
                ],
        ),
        value: '${_count.format(onFoot.round())} km',
        detail: '${comparison[0].toUpperCase()}${comparison.substring(1)}'
            '${hasSteps ? ' (${_count.format(steps)} steps)' : ''}',
      ));
    }

    // Sleep records.
    final longest = await db.rawQuery(
      'SELECT date, totalHours FROM sleep_entries WHERE $inRange AND totalHours IS NOT NULL ORDER BY totalHours DESC LIMIT 1',
      args,
    );
    final wakes = await db.query('sleep_entries', columns: ['date', 'wakeUpTime'], where: '$inRange AND wakeUpTime IS NOT NULL', whereArgs: args);
    if (longest.isNotEmpty && wakes.length >= 5) {
      DateTime wakeOf(Map<String, Object?> r) => DateTime.parse(r['wakeUpTime'] as String);
      // Earliest by clock time, ignoring wake-ups after noon (naps, typos).
      final mornings = wakes.where((r) => wakeOf(r).hour < 12).toList()
        ..sort((a, b) => (wakeOf(a).hour * 60 + wakeOf(a).minute).compareTo(wakeOf(b).hour * 60 + wakeOf(b).minute));
      final minutes = ((longest.first['totalHours'] as num) * 60).round();
      facts.add(FunFact(
        kind: FactKind.sleep,
        title: 'Longest night',
        details: () async => FactDetail(
          title: 'Nights by length',
          rows: [
            for (final r in await db.rawQuery(
              'SELECT date, totalHours, sleepTime, wakeUpTime FROM sleep_entries WHERE $inRange AND totalHours IS NOT NULL',
              args,
            ))
              FactRow(
                label: DateFormat('EEE d MMM y').format(DateTime.parse(r['date'] as String)),
                sub: r['wakeUpTime'] == null ? null : 'Woke ${DateFormat('HH:mm').format(DateTime.parse(r['wakeUpTime'] as String))}',
                date: DateTime.parse(r['date'] as String),
                value: r['totalHours'] as num,
                valueText: _hours(r['totalHours'] as num),
              ),
          ],
        ),
        value: '${minutes ~/ 60}h ${minutes % 60}m',
        detail: '${_day.format(DateTime.parse(longest.first['date'] as String))}'
            '${mornings.isEmpty ? '' : '. Earliest start: ${DateFormat('HH:mm').format(wakeOf(mornings.first))} '
                'on ${_day.format(DateTime.parse(mornings.first['date'] as String))}'}',
      ));
    }

    // Logging: days with a plant (the garden's rule for a logged day), and
    // the longest run of them.
    final garden = await GardenRepository(_db).daysInRange(from, last);
    final logged = {for (final g in garden) if (g.plant.logged) g.date};
    final days = daysBetween(from, to);
    if (logged.length >= 3) {
      var run = 0, best = 0;
      for (final g in garden) {
        run = g.plant.logged ? run + 1 : 0;
        if (run > best) best = run;
      }
      final missed = [
        for (final g in garden)
          if (!g.plant.logged && !g.date.isAfter(dayOf(today ?? DateTime.now()))) g.date,
      ];
      facts.add(FunFact(
        kind: FactKind.logging,
        title: 'Days logged',
        details: () async => FactDetail(
          title: 'Days not logged',
          byDate: true,
          note: missed.isEmpty ? 'Every day in this period has something logged.' : null,
          rows: [for (final d in missed) FactRow(label: DateFormat('EEEE d MMMM y').format(d), date: d)],
        ),
        value: '${logged.length} of $days',
        detail: best >= 3 ? 'Longest run: $best days in a row' : 'Every day logged adds a plant',
      ));
    }

    // A food that keeps turning up on the same weekday.
    final byWeekday = <(int, String), int>{};
    final perFood = <String, int>{};
    for (final r in await db.rawQuery('''
      SELECT m.date, COALESCE(f.name, m.name) AS name FROM meal_entries m
      LEFT JOIN food_items f ON f.id = m.food_item_id WHERE m.$inRange
    ''', args)) {
      final name = r['name'] as String;
      final weekday = DateTime.parse(r['date'] as String).weekday;
      byWeekday[(weekday, name)] = (byWeekday[(weekday, name)] ?? 0) + 1;
      perFood[name] = (perFood[name] ?? 0) + 1;
    }
    final habits = [
      for (final MapEntry(key: (weekday, name), value: n) in byWeekday.entries)
        if (n >= 3 && n / perFood[name]! >= 0.5) (weekday, name, n),
    ]..sort((a, b) => b.$3.compareTo(a.$3));
    if (habits.isNotEmpty) {
      final (weekday, name, n) = habits.first;
      final dayName = DateFormat('EEEE').format(DateTime(2024, 1, weekday)); // 1 Jan 2024 was a Monday
      facts.add(FunFact(
        kind: FactKind.weekday,
        title: '${dayName}s are for',
        value: name,
        detail: '$n of ${perFood[name]} times on a $dayName',
        details: () async => _weekdays(db, inRange, args),
      ));
    }

    // The garden's mix of plants.
    final grown = [for (final g in garden) if (g.plant.logged) g.plant];
    if (grown.length >= 3) {
      final counts = <PlantSpecies, int>{};
      for (final p in grown) {
        counts[p.species] = (counts[p.species] ?? 0) + 1;
      }
      final mix = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      // Named as they grew in a week or month; a longer period uses the family's summer name.
      final season = last.difference(from).inDays <= 92 ? Season.of(from.add(Duration(days: last.difference(from).inDays ~/ 2))) : Season.summer;
      facts.add(FunFact(
        kind: FactKind.garden,
        title: 'The garden grew',
        details: () async => FactDetail(
          title: 'Plants by kind',
          rows: [
            for (final e in mix)
              FactRow(label: e.key.label, sub: e.key.pluralIn(season), value: e.value, valueText: '${e.value}'),
          ],
        ),
        value: '${grown.length} ${grown.length == 1 ? 'plant' : 'plants'}',
        detail: mix.take(3).map((e) => '${e.value} ${e.value == 1 ? e.key.nameIn(season) : e.key.pluralIn(season)}').join(', '),
      ));
    }

    // On this day in earlier years.
    // A memory fits a short look back, not a year or all time.
    if (!range.isAllTime && range.daysCount <= 31) {
      final memory = await _onThisDay(db, dayOf(today ?? DateTime.now()));
      if (memory != null) facts.add(memory);
    }

    return facts;
  }

  static String _hours(num hours) {
    final minutes = (hours * 60).round();
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  /// For each weekday, the foods and activities that lean to it: done at
  /// least 3 times on that day and at least twice as often as an even
  /// spread over the week would give.
  Future<FactDetail> _weekdays(DatabaseExecutor db, String inRange, List<Object?> args) async {
    final onDay = <(int, String, String), int>{}; // (weekday, kind, name)
    final total = <(String, String), int>{};
    void count(String date, String kind, String name) {
      final weekday = DateTime.parse(date).weekday;
      onDay[(weekday, kind, name)] = (onDay[(weekday, kind, name)] ?? 0) + 1;
      total[(kind, name)] = (total[(kind, name)] ?? 0) + 1;
    }

    for (final r in await db.rawQuery('''
      SELECT m.date, COALESCE(f.name, m.name) AS name FROM meal_entries m
      LEFT JOIN food_items f ON f.id = m.food_item_id WHERE m.$inRange
    ''', args)) {
      count(r['date'] as String, 'food', r['name'] as String);
    }
    for (final r in await db.rawQuery('''
      SELECT a.date, t.name FROM activity_entries a JOIN tags t ON t.id = a.tagId WHERE a.$inRange
    ''', args)) {
      count(r['date'] as String, 'activity', r['name'] as String);
    }

    final leaning = [
      for (final MapEntry(key: (weekday, kind, name), value: n) in onDay.entries)
        if (n >= 3 && n / total[(kind, name)]! >= 2 / 7) (weekday, kind, name, n, total[(kind, name)]!),
    ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : (b.$4 / b.$5).compareTo(a.$4 / a.$5));
    String dayName(int weekday) => DateFormat('EEEE').format(DateTime(2024, 1, weekday)); // 1 Jan 2024 was a Monday
    return FactDetail(
      title: 'What each weekday is for',
      note: 'Foods and activities done at least twice as often on one weekday as the others.',
      rows: [
        for (final (weekday, kind, name, n, all) in leaning)
          FactRow(
            label: name,
            sub: '${kind == 'food' ? 'Food' : 'Activity'} · $n of $all times',
            value: n / all,
            valueText: '${(n / all * 100).round()}%',
            group: '${dayName(weekday)}s',
          ),
      ],
    );
  }

  /// The most recent earlier year with something logged on this date: a
  /// moment's words if there are any, otherwise what was eaten.
  Future<FunFact?> _onThisDay(DatabaseExecutor db, DateTime today) async {
    for (var years = 1; years <= 10; years++) {
      final then = DateTime(today.year - years, today.month, today.day);
      if (then.month != today.month) continue; // 29 February
      final date = then.toIso8601String();
      final moments = await db.rawQuery(
        "SELECT text FROM journal_entries WHERE date = ? AND text != '' ORDER BY time LIMIT 1",
        [date],
      );
      final meals = await db.rawQuery('SELECT name FROM meal_entries WHERE date = ? ORDER BY time LIMIT 3', [date]);
      if (moments.isEmpty && meals.isEmpty) continue;
      final words = moments.isNotEmpty
          ? '“${moments.first['text']}”'
          : 'You had ${meals.map((r) => r['name']).join(', ')}';
      return FunFact(
        kind: FactKind.memory,
        title: 'On this day',
        value: years == 1 ? 'A year ago' : '$years years ago',
        detail: words,
      );
    }
    return null;
  }
}
