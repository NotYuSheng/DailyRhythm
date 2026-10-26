import '../../../../shared/services/database/database_service.dart';
import '../../../../shared/services/database/repositories/health_repository.dart';
import '../../../../shared/utils/date_utils.dart';
import '../models/metric_data.dart';

/// The four ways a day is rated: mood from 1 to 5, and energy, stress and
/// focus compared with a usual day, from -2 (much lower) to +2.
enum Rating {
  mood('Mood', 1, 5, ['Awful', 'Bad', 'Okay', 'Good', 'Great']),
  energy('Energy', -2, 2, _relative),
  stress('Stress', -2, 2, _relative),
  focus('Focus', -2, 2, _relative);

  const Rating(this.label, this.min, this.max, this.words);

  final String label;
  final int min;
  final int max;

  /// A word for each value from [min] to [max].
  final List<String> words;

  String wordFor(int value) => words[value - min];

  /// The word nearest an average, for "mostly usual".
  String wordNear(double average) => wordFor(average.round().clamp(min, max));
}

const _relative = ['Much lower', 'Lower', 'Usual', 'Higher', 'Much higher'];

/// One day's ratings and tags.
class RatedDay {
  const RatedDay(this.date, this.ratings, this.tags);

  final DateTime date;
  final Map<Rating, int> ratings;
  final Set<String> tags;
}

/// How one rating went over a period.
class RatingSummary {
  const RatingSummary({required this.rating, required this.counts, this.previousAverage});

  final Rating rating;

  /// Days per value, from [Rating.min] to [Rating.max].
  final Map<int, int> counts;
  final double? previousAverage;

  int get days => counts.values.fold(0, (sum, n) => sum + n);

  double? get average =>
      days == 0 ? null : counts.entries.fold<int>(0, (sum, e) => sum + e.key * e.value) / days;
}

/// A rating on days with a tag against days without it.
class TagComparison {
  const TagComparison({
    required this.tag,
    required this.rating,
    required this.withDays,
    required this.withoutDays,
    required this.withAverage,
    required this.withoutAverage,
  });

  final String tag;
  final Rating rating;
  final int withDays;
  final int withoutDays;
  final double withAverage;
  final double withoutAverage;

  double get difference => withAverage - withoutAverage;

  /// Stated as what was rated, never as a cause:
  /// "Energy averaged +0.6 on 8 days with Gym and -0.1 on 22 other days."
  String get text {
    String fmt(double v) => rating == Rating.mood ? v.toStringAsFixed(1) : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}';
    return '${rating.label} averaged ${fmt(withAverage)} on $withDays days with $tag '
        'and ${fmt(withoutAverage)} on $withoutDays other days';
  }
}

/// A watch metric's daily average over a period.
class WatchAverage {
  const WatchAverage({required this.metric, required this.days, required this.average, this.previousAverage});

  final WatchMetric metric;
  final int days;
  final double average;
  final double? previousAverage;
}

/// Watch metrics shown on Metrics, when the watch recorded them.
enum WatchMetric {
  steps('steps', 'Steps', ''),
  sleep('sleep_minutes', 'Sleep', 'h'),
  restingHr('resting_hr', 'Resting heart rate', 'bpm'),
  stress('stress_avg', 'Stress (watch)', ''),
  bodyBattery('body_battery_high', 'Body Battery peak', ''),
  intensity('intensity_minutes', 'Intensity minutes', 'min');

  const WatchMetric(this.key, this.label, this.unit);

  final String key;
  final String label;
  final String unit;

  /// Sleep is stored in minutes but read in hours.
  double display(double value) => this == sleep ? value / 60 : value;
}

class DayRatingsReport {
  const DayRatingsReport({required this.summaries, required this.comparisons, required this.watch});

  final List<RatingSummary> summaries;
  final List<TagComparison> comparisons;
  final List<WatchAverage> watch;
}

/// Mood, energy, stress and focus over a period, how they differ on days
/// with each tag, and watch averages. Comparisons only describe what was
/// logged; they need [minDays] days both with and without a tag.
class DayRatingsService {
  DayRatingsService(this._db);

  final DatabaseService _db;

  static const minDays = 5;

  /// Smallest difference worth showing, on each rating's own scale.
  static const minDifference = {Rating.mood: 0.5, Rating.energy: 0.4, Rating.stress: 0.4, Rating.focus: 0.4};

  Future<DayRatingsReport> reportFor(DateRange range) async {
    final days = await ratedDays(range.start, range.end);
    final length = daysBetween(range.start, range.end) + 1;
    final previousEnd = DateTime(range.start.year, range.start.month, range.start.day - 1);
    final previousStart = DateTime(previousEnd.year, previousEnd.month, previousEnd.day - length + 1);
    final previous = await ratedDays(previousStart, previousEnd);

    final health = HealthRepository(_db);
    final watch = <WatchAverage>[];
    for (final metric in WatchMetric.values) {
      final now = await health.series(metric.key, range.start, range.end);
      if (now.length < 3) continue;
      final before = await health.series(metric.key, previousStart, previousEnd);
      double avg(List<double> v) => v.reduce((a, b) => a + b) / v.length;
      watch.add(WatchAverage(
        metric: metric,
        days: now.length,
        average: metric.display(avg([for (final m in now) m.value])),
        previousAverage: before.length < 3 ? null : metric.display(avg([for (final m in before) m.value])),
      ));
    }

    return DayRatingsReport(
      summaries: [for (final r in Rating.values) summarize(r, days, previous)],
      comparisons: compareTags(days),
      watch: watch,
    );
  }

  /// Every day from [start] to [end] with at least one rating.
  Future<List<RatedDay>> ratedDays(DateTime start, DateTime end) async {
    final db = await _db.database;
    final from = dayOf(start);
    final last = dayOf(end);
    final args = [from.toIso8601String(), DateTime(last.year, last.month, last.day + 1).toIso8601String()];
    const inRange = 'date >= ? AND date < ?';
    DateTime day(Object? iso) => dayOf(DateTime.parse(iso as String));

    final ratings = <DateTime, Map<Rating, int>>{};
    for (final r in await db.query('mood_entries', columns: ['date', 'moodLevel'], where: inRange, whereArgs: args, orderBy: 'id')) {
      (ratings[day(r['date'])] ??= {})[Rating.mood] = r['moodLevel'] as int;
    }
    for (final r in await db.query('day_checkins', where: inRange, whereArgs: args)) {
      final values = ratings[day(r['date'])] ??= {};
      for (final (rating, column) in [(Rating.energy, 'energy'), (Rating.stress, 'stress'), (Rating.focus, 'focus')]) {
        if (r[column] case final int v) values[rating] = v;
      }
    }
    final tags = <DateTime, Set<String>>{};
    for (final r in await db.rawQuery(
      'SELECT a.date, t.name FROM activity_entries a JOIN tags t ON t.id = a.tagId WHERE a.$inRange',
      args,
    )) {
      (tags[day(r['date'])] ??= {}).add(r['name'] as String);
    }
    return [
      for (final MapEntry(key: date, value: values) in ratings.entries)
        if (values.isNotEmpty) RatedDay(date, values, tags[date] ?? const {}),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  static RatingSummary summarize(Rating rating, List<RatedDay> days, [List<RatedDay> previous = const []]) {
    final counts = {for (var v = rating.min; v <= rating.max; v++) v: 0};
    for (final d in days) {
      if (d.ratings[rating] case final v?) counts[v] = (counts[v] ?? 0) + 1;
    }
    final before = [for (final d in previous) ?d.ratings[rating]];
    return RatingSummary(
      rating: rating,
      counts: counts,
      previousAverage: before.length < minDays ? null : before.reduce((a, b) => a + b) / before.length,
    );
  }

  /// For each tag and rating, the average on days with the tag against
  /// days without it, when both have [minDays] days and the difference is
  /// at least [minDifference]. Largest differences first, one per tag.
  static List<TagComparison> compareTags(List<RatedDay> days, {int limit = 6}) {
    final allTags = {for (final d in days) ...d.tags};
    final best = <String, TagComparison>{};
    for (final rating in Rating.values) {
      final rated = [for (final d in days) if (d.ratings.containsKey(rating)) d];
      for (final tag in allTags) {
        final withTag = [for (final d in rated) if (d.tags.contains(tag)) d.ratings[rating]!];
        final without = [for (final d in rated) if (!d.tags.contains(tag)) d.ratings[rating]!];
        if (withTag.length < minDays || without.length < minDays) continue;
        double avg(List<int> v) => v.reduce((a, b) => a + b) / v.length;
        final c = TagComparison(
          tag: tag,
          rating: rating,
          withDays: withTag.length,
          withoutDays: without.length,
          withAverage: avg(withTag),
          withoutAverage: avg(without),
        );
        if (c.difference.abs() < minDifference[rating]!) continue;
        final current = best[tag];
        // Scales are the same width (4), so differences compare directly.
        if (current == null || c.difference.abs() > current.difference.abs()) best[tag] = c;
      }
    }
    return (best.values.toList()..sort((a, b) => b.difference.abs().compareTo(a.difference.abs()))).take(limit).toList();
  }
}
