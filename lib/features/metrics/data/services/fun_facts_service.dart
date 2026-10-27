import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../shared/services/database/database_service.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../garden/data/garden_repository.dart';
import '../../../garden/domain/plant.dart';
import '../../../../shared/services/database/repositories/health_repository.dart';
import '../models/metric_data.dart';

/// What a fun fact is about, for its icon and colour.
enum FactKind { food, newFood, spend, events, exercise, distance, sleep, logging, weekday, garden, memory }

/// One light-hearted observation about a period: a headline value and a
/// line of detail. Facts state what was logged; they never give advice.
class FunFact {
  const FunFact({required this.kind, required this.title, required this.value, required this.detail});

  final FactKind kind;
  final String title;
  final String value;
  final String detail;

  @override
  String toString() => '$title: $value ($detail)';
}

/// Familiar distances for turning kilometres into something to picture.
const distanceLandmarks = [
  (42.195, 'a marathon'),
  (50.0, 'Singapore from Tuas to Changi'),
  (315.0, 'Singapore to Kuala Lumpur'),
  (1250.0, 'Singapore to Bangkok'),
  (2900.0, 'Singapore to Hong Kong'),
  (5300.0, 'Singapore to Tokyo'),
];

/// "about 2.4 times a marathon", "about Singapore to Kuala Lumpur".
String distanceComparison(double km) {
  var best = distanceLandmarks.first;
  for (final landmark in distanceLandmarks) {
    if (km >= landmark.$1 * 0.95) best = landmark;
  }
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

  Future<List<FunFact>> factsFor(DateRange range, {DateTime? today}) async {
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
    if ((spend.first['priced'] as int) >= 5 && priciest.isNotEmpty) {
      final p = priciest.first;
      facts.add(FunFact(
        kind: FactKind.spend,
        title: 'Biggest treat',
        value: '\$${_money.format(p['price'])}',
        detail: '${p['name']}, ${_day.format(DateTime.parse(p['date'] as String))}. '
            '\$${_money.format(spend.first['total'])} on food in all',
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
        value: '\$${_money.format(events['total'])}',
        detail: events['n'] == 1
            ? '${top['label']}, ${_day.format(DateTime.parse(top['date'] as String))}'
            : '${events['n']} of them. The biggest: ${top['label']}',
      ));
    }

    // Most repeated exercise by total reps.
    final reps = await db.rawQuery('''
      SELECT COALESCE(x.name, e.exerciseName) AS name, SUM(e.reps * MAX(COALESCE(e.sets, 1), 1)) AS total
      FROM exercise_entries e LEFT JOIN exercise_items x ON x.id = e.exercise_item_id
      WHERE e.$inRange AND e.reps IS NOT NULL AND COALESCE(x.name, e.exerciseName) IS NOT NULL
      GROUP BY lower(COALESCE(x.name, e.exerciseName)) ORDER BY total DESC LIMIT 1
    ''', args);
    if (reps.isNotEmpty && (reps.first['total'] as num) >= 50) {
      facts.add(FunFact(
        kind: FactKind.exercise,
        title: 'Most reps',
        value: _count.format(reps.first['total']),
        detail: '${reps.first['name']}',
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
      final comparison = distanceComparison(onFoot);
      facts.add(FunFact(
        kind: FactKind.distance,
        title: hasSteps ? 'Distance on foot' : 'Distance run',
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
      facts.add(FunFact(
        kind: FactKind.logging,
        title: 'Days logged',
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
      facts.add(FunFact(kind: FactKind.weekday, title: '${dayName}s are for', value: name, detail: '$n of ${perFood[name]} times on a $dayName'));
    }

    // The garden's mix of plants.
    final grown = [for (final g in garden) if (g.plant.logged) g.plant];
    if (grown.length >= 3) {
      final counts = <PlantSpecies, int>{};
      for (final p in grown) {
        counts[p.species] = (counts[p.species] ?? 0) + 1;
      }
      final mix = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      facts.add(FunFact(
        kind: FactKind.garden,
        title: 'The garden grew',
        value: '${grown.length} ${grown.length == 1 ? 'plant' : 'plants'}',
        detail: mix.take(3).map((e) => '${e.value} ${e.value == 1 ? e.key.plantName : e.key.pluralName}').join(', '),
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
