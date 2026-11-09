import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/services/database/database_service.dart';
import '../../../../shared/services/database/repositories/catalog_repository.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../garden/data/garden_repository.dart';
import '../../../meals/domain/diet_score.dart';
import '../models/metric_data.dart';
import 'day_ratings_service.dart';

/// A period's days sorted into five levels (0 lowest … 4 highest): how
/// many at each, how many on each weekday at each, and a day's value on
/// average, against the period before.
class LevelReport {
  const LevelReport({
    required this.byLevel,
    required this.byWeekday,
    required this.days,
    this.average,
    this.perWeek,
    this.previousPerWeek,
    this.previousAverage,
  });

  /// Days at each level, lowest first (5 counts).
  final List<int> byLevel;

  /// For each weekday (Monday first), its days at each level.
  final List<List<int>> byWeekday;

  /// Days in the period.
  final int days;

  /// The average value of the days with one (calories a day), if values
  /// were given.
  final double? average;

  /// Days with a value a week, this period and the one before (null for
  /// all time, or with nothing logged before).
  final double? perWeek;
  final double? previousPerWeek;
  final double? previousAverage;

  int get counted => byLevel.fold(0, (a, b) => a + b);

  /// The middle level of the counted days, or null without any.
  int? get usual {
    if (counted == 0) return null;
    var seen = 0;
    for (var i = 0; i < 5; i++) {
      seen += byLevel[i];
      if (seen * 2 >= counted) return i;
    }
    return 4;
  }

  /// The weekday (1 Monday … 7 Sunday) with the most counted days, when one
  /// stands out.
  int? get busiestWeekday {
    final totals = [for (final w in byWeekday) w.fold(0, (a, b) => a + b)];
    final most = totals.reduce((a, b) => a > b ? a : b);
    if (most == 0 || totals.where((t) => t == most).length > 1) return null;
    return totals.indexOf(most) + 1;
  }

  /// [levels] (0–4) of the period's days, by date, over a period [days]
  /// long; [values] their values when there are any (calories). The same
  /// for the period before when it's given.
  static LevelReport from(
    Map<DateTime, int> levels, {
    required int days,
    Map<DateTime, double>? values,
    Map<DateTime, int>? previous,
    int? previousDays,
    Map<DateTime, double>? previousValues,
    bool hadPrevious = true,
  }) {
    final byLevel = List.filled(5, 0);
    final byWeekday = [for (var i = 0; i < 7; i++) List.filled(5, 0)];
    for (final MapEntry(key: day, value: level) in levels.entries) {
      final l = level.clamp(0, 4);
      byLevel[l]++;
      byWeekday[day.weekday - 1][l]++;
    }
    double? mean(Map<DateTime, double>? v) => v == null || v.isEmpty ? null : v.values.reduce((a, b) => a + b) / v.length;
    final compare = previous != null && previousDays != null && previousDays > 0 && hadPrevious;
    return LevelReport(
      byLevel: byLevel,
      byWeekday: byWeekday,
      days: days,
      average: mean(values),
      perWeek: compare && days > 0 ? levels.length / days * 7 : null,
      previousPerWeek: compare ? previous.length / previousDays * 7 : null,
      previousAverage: compare ? mean(previousValues) : null,
    );
  }
}

/// The calendar period before [range], of the same kind (week, month or
/// year); null for all time.
DateRange? previousPeriod(DateRange range) {
  if (range.isAllTime) return null;
  final before = DateTime(range.start.year, range.start.month, range.start.day - 1);
  // The labels say which kind it is: "2026", "3–9 Nov" or "November 2026".
  if (range.label == '${range.start.year}') return DateRange.year(before);
  if (range.label.contains('–')) return DateRange.week(before);
  return DateRange.month(before);
}

/// "last week", "last month" or "last year" for the period before [range].
String previousWord(DateRange range) => range.label == '${range.start.year}'
    ? 'last year'
    : range.label.contains('–')
        ? 'last week'
        : 'last month';

/// The days a [range] covers: all time from the first entry, never past today.
Future<(DateTime, DateTime)> _span(DatabaseService db, DateRange range) async {
  final first = range.isAllTime ? await db.firstLoggedDay() : null;
  final today = dayOf(DateTime.now());
  final end = dayOf(range.end).isAfter(today) ? today : dayOf(range.end);
  return (dayOf(first ?? range.start), end);
}

/// Exercise effort (1–5 as Today rates it, here 0–4) of each day with
/// exercise.
Future<Map<DateTime, int>> _effort(DatabaseService db, DateTime start, DateTime end) async => {
      for (final l in await GardenRepository(db).logsInRange(start, end))
        if (l.effort != null) l.date: l.effort! - 1,
    };

/// Calories eaten each day with a meal that has calories.
Future<Map<DateTime, double>> dailyKcal(DatabaseService db, DateTime start, DateTime end) async {
  final foodKcal = await CatalogRepository(db).foodCalories();
  final kcal = <DateTime, double>{};
  for (final m in await db.getMealEntriesInRange(start, end)) {
    if (m.caloriesWith(foodKcal) case final c?) kcal[dayOf(m.date)] = (kcal[dayOf(m.date)] ?? 0) + c;
  }
  return kcal;
}

final effortReportProvider = FutureProvider.autoDispose.family<LevelReport, DateRange>((ref, range) async {
  final db = ref.watch(databaseProvider);
  final (start, end) = await _span(db, range);
  final days = daysBetween(start, end) + 1;
  final now = await _effort(db, start, end);
  final before = previousPeriod(range);
  if (before == null) return LevelReport.from(now, days: days);
  final (bStart, bEnd) = (dayOf(before.start), dayOf(before.end));
  final first = await db.firstLoggedDay();
  return LevelReport.from(
    now,
    days: days,
    previous: await _effort(db, bStart, bEnd),
    previousDays: daysBetween(bStart, bEnd) + 1,
    hadPrevious: first != null && !first.isAfter(bEnd),
  );
});

/// The calorie band (0–4) of a day's [kcal], as the overview colours it:
/// against the user's range ([low]–[high]) when there is one, with 400
/// either side counting as well under or over; else fixed bands.
int calorieBand(double kcal, {double? low, double? high}) {
  final cuts = low != null && high != null ? [low - 400, low, high + 0.5, high + 400] : const [1600.0, 1900.0, 2200.0, 2500.0];
  var i = 0;
  while (i < cuts.length && kcal >= cuts[i]) {
    i++;
  }
  return i;
}

/// Each day's calories and its band; the key is the period and the user's
/// calorie range (low, high), if any.
final calorieReportProvider = FutureProvider.autoDispose.family<LevelReport, (DateRange, double?, double?)>((ref, key) async {
  final (range, low, high) = key;
  int band(double v) => calorieBand(v, low: low, high: high);
  final db = ref.watch(databaseProvider);
  final (start, end) = await _span(db, range);
  final kcal = await dailyKcal(db, start, end);
  final before = previousPeriod(range);
  final previous = before == null ? null : await dailyKcal(db, dayOf(before.start), dayOf(before.end));
  return LevelReport.from(
    {for (final e in kcal.entries) e.key: band(e.value)},
    days: daysBetween(start, end) + 1,
    values: kcal,
    previous: previous == null ? null : {for (final e in previous.entries) e.key: band(e.value)},
    previousDays: before == null ? null : daysBetween(dayOf(before.start), dayOf(before.end)) + 1,
    previousValues: previous,
    hadPrevious: previous != null && previous.isNotEmpty,
  );
});

/// How healthy each day's meals were (1–5, here 0–4), with the score as
/// the value for averages.
final healthReportProvider = FutureProvider.autoDispose.family<LevelReport, DateRange>((ref, range) async {
  final db = ref.watch(databaseProvider);
  Future<Map<DateTime, double>> scores(DateTime start, DateTime end) async => {
        for (final l in await GardenRepository(db).logsInRange(start, end))
          if (DietScore.levelFor(l.diet) != null) l.date: l.diet!,
      };
  final (start, end) = await _span(db, range);
  final now = await scores(start, end);
  final before = previousPeriod(range);
  final previous = before == null ? null : await scores(dayOf(before.start), dayOf(before.end));
  Map<DateTime, int> levels(Map<DateTime, double> v) => {for (final e in v.entries) e.key: DietScore.levelFor(e.value)! - 1};
  return LevelReport.from(
    levels(now),
    days: daysBetween(start, end) + 1,
    values: now,
    previous: previous == null ? null : levels(previous),
    previousDays: before == null ? null : daysBetween(dayOf(before.start), dayOf(before.end)) + 1,
    previousValues: previous,
    hadPrevious: previous != null && previous.isNotEmpty,
  );
});

/// One way days are rated (mood, energy, stress or focus): each rated
/// day's value as a level 0–4, the value itself for averages.
final ratingReportProvider = FutureProvider.autoDispose.family<LevelReport, (DateRange, Rating)>((ref, key) async {
  final (range, rating) = key;
  final db = ref.watch(databaseProvider);
  final service = DayRatingsService(db);
  Future<Map<DateTime, int>> values(DateTime start, DateTime end) async => {
        for (final d in await service.ratedDays(start, end))
          if (d.ratings[rating] case final v?) d.date: v,
      };
  final (start, end) = await _span(db, range);
  final now = await values(start, end);
  final before = previousPeriod(range);
  final previous = before == null ? null : await values(dayOf(before.start), dayOf(before.end));
  Map<DateTime, int> levels(Map<DateTime, int> v) => {for (final e in v.entries) e.key: e.value - rating.min};
  Map<DateTime, double> raw(Map<DateTime, int> v) => {for (final e in v.entries) e.key: e.value.toDouble()};
  return LevelReport.from(
    levels(now),
    days: daysBetween(start, end) + 1,
    values: raw(now),
    previous: previous == null ? null : levels(previous),
    previousDays: before == null ? null : daysBetween(dayOf(before.start), dayOf(before.end)) + 1,
    previousValues: previous == null ? null : raw(previous),
    hadPrevious: previous != null && previous.isNotEmpty,
  );
});
