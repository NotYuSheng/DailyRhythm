import 'dart:math' as math;

import '../../../shared/utils/date_utils.dart';
import '../../metrics/data/models/metric_data.dart';

/// What one day of the year held, for the year in pixels.
class DayValues {
  DayValues(this.date);

  final DateTime date;
  double? sleepHours;
  double? steps;
  double? kcal;
  int? mood;
  int? energy;
}

/// A night: when sleep started and ended, as hours after 18:00 the evening
/// before (00:30 is 6.5, 07:00 is 13), on the day it ended. From 18:00 to
/// 14:00 the next day holds early nights and late lie-ins alike.
class NightSpan {
  const NightSpan(this.day, this.bed, this.wake);

  final DateTime day;
  final double bed;
  final double wake;

  /// Hours after 18:00 the axis spans.
  static const span = 20.0;

  /// Clock time as hours after 18:00, for the schedule chart's axis.
  static double fromClock(DateTime time) => (time.hour + time.minute / 60 - 18 + 24) % 24;
}

/// A month's usual sleep: the median bedtime and wake time, the middle
/// half of each, and the average length.
class MonthSleep {
  const MonthSleep({
    required this.month,
    required this.bed,
    required this.wake,
    required this.bedLow,
    required this.bedHigh,
    required this.wakeLow,
    required this.wakeHigh,
    required this.hours,
  });

  final int month;
  final double bed;
  final double wake;
  final double bedLow;
  final double bedHigh;
  final double wakeLow;
  final double wakeHigh;
  final double? hours;
}

/// A month's averages and spending, for the month table.
class MonthRow {
  const MonthRow({required this.month, required this.days, this.sleep, this.steps, this.kcal, required this.food, required this.events});

  final int month;

  /// Days logged: the plants in the month's garden.
  final int days;
  final double? sleep;
  final double? steps;
  final double? kcal;
  final double food;
  final double events;
}

/// A tag the user logs only some days, and which days.
class RareTag {
  const RareTag(this.name, this.days);

  final String name;
  final List<DateTime> days;
}

/// A year at a glance: every day's values, mood and sleep by month, the
/// tags that stood out, and a row per month. Built from plain inputs so it
/// can be tested without a database.
class YearOverview {
  YearOverview._({
    required this.year,
    required this.days,
    required this.loggedDays,
    required this.moodByMonth,
    required this.sleepByMonth,
    required this.rareTags,
    required this.everydayTags,
    required this.months,
  });

  final int year;

  /// Every day of the year up to today, logged or not.
  final List<DayValues> days;
  final int loggedDays;

  /// Days per mood (1–5) for each month, January first.
  final List<List<int>> moodByMonth;
  final List<MonthSleep> sleepByMonth;

  /// Tags on fewer than [everydayShare] of logged days, most used first.
  final List<RareTag> rareTags;

  /// Tags on most days, left out of [rareTags] and named instead.
  final List<String> everydayTags;
  final List<MonthRow> months;

  static const maxRareTags = 5;

  /// Anything to show: logged days, or watch data alone.
  bool get hasData => loggedDays > 0 || months.isNotEmpty;

  double? get averageSleep => _mean([for (final d in days) ?d.sleepHours]);
  double? get averageSteps => _mean([for (final d in days) ?d.steps]);

  factory YearOverview.build({
    required int year,
    required DateTime today,
    required Set<DateTime> logged,
    required Map<DateTime, double> sleepHours,
    required Map<DateTime, double> steps,
    required Map<DateTime, double> kcal,
    required Map<DateTime, int> moods,
    required Map<DateTime, int> energy,
    required List<NightSpan> nights,
    required Map<String, Set<DateTime>> tagDays,
    required Map<DateTime, double> foodSpend,
    required Map<DateTime, double> eventSpend,
  }) {
    final end = dayOf(today);
    final days = <DayValues>[
      for (var d = DateTime(year); d.year == year && !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1))
        DayValues(d)
          ..sleepHours = sleepHours[d]
          ..steps = steps[d]
          ..kcal = kcal[d]
          ..mood = moods[d]
          ..energy = energy[d],
    ];
    final inYear = {for (final d in logged) if (d.year == year && !d.isAfter(end)) d};

    // One pass over each map, bucketed by month.
    final moodByMonth = [for (var m = 0; m < 12; m++) List.filled(5, 0)];
    for (final MapEntry(key: day, value: level) in moods.entries) {
      if (day.year == year && level >= 1 && level <= 5) moodByMonth[day.month - 1][level - 1]++;
    }
    List<List<double>> byMonth(Map<DateTime, double> values) {
      final out = [for (var m = 0; m < 12; m++) <double>[]];
      for (final MapEntry(key: day, value: v) in values.entries) {
        if (day.year == year) out[day.month - 1].add(v);
      }
      return out;
    }

    final sleepMonths = byMonth(sleepHours);

    final sleepByMonth = <MonthSleep>[];
    for (var m = 1; m <= 12; m++) {
      final month = [for (final n in nights) if (n.day.year == year && n.day.month == m) n];
      if (month.isEmpty) continue;
      final beds = [for (final n in month) n.bed];
      final wakes = [for (final n in month) n.wake];
      sleepByMonth.add(MonthSleep(
        month: m,
        bed: _quantile(beds, 0.5),
        wake: _quantile(wakes, 0.5),
        bedLow: _quantile(beds, 0.25),
        bedHigh: _quantile(beds, 0.75),
        wakeLow: _quantile(wakes, 0.25),
        wakeHigh: _quantile(wakes, 0.75),
        hours: _mean(sleepMonths[m - 1]),
      ));
    }

    final everyday = <String>[];
    final rare = <RareTag>[];
    for (final MapEntry(key: name, value: dates) in tagDays.entries) {
      final used = [for (final d in dates) if (inYear.contains(d)) d]..sort();
      if (used.isEmpty) continue;
      // The same rule as Metrics' "Most days".
      if (inYear.length >= ActivityMetrics.everydayMinDays && used.length >= inYear.length * ActivityMetrics.everydayShare) {
        everyday.add(name);
      } else {
        rare.add(RareTag(name, used));
      }
    }
    rare.sort((a, b) => b.days.length.compareTo(a.days.length));
    everyday.sort();

    final stepMonths = byMonth(steps);
    final kcalMonths = byMonth(kcal);
    final foodMonths = byMonth(foodSpend);
    final eventMonths = byMonth(eventSpend);
    final loggedPerMonth = List.filled(12, 0);
    for (final d in inYear) {
      loggedPerMonth[d.month - 1]++;
    }
    final hasValues = List.generate(12, (i) => sleepMonths[i].isNotEmpty || stepMonths[i].isNotEmpty);
    final months = [
      for (var m = 1; m <= 12; m++)
        // Months with logs, or watch data alone.
        if (loggedPerMonth[m - 1] > 0 || hasValues[m - 1])
          MonthRow(
            month: m,
            days: loggedPerMonth[m - 1],
            sleep: _mean(sleepMonths[m - 1]),
            steps: _mean(stepMonths[m - 1]),
            kcal: _mean(kcalMonths[m - 1]),
            food: foodMonths[m - 1].fold(0.0, (s, v) => s + v),
            events: eventMonths[m - 1].fold(0.0, (s, v) => s + v),
          ),
    ];

    return YearOverview._(
      year: year,
      days: days,
      loggedDays: inYear.length,
      moodByMonth: moodByMonth,
      sleepByMonth: sleepByMonth,
      rareTags: rare.take(maxRareTags).toList(),
      everydayTags: everyday,
      months: months,
    );
  }

  static double? _mean(List<double> values) => values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

  static double _quantile(List<double> values, double q) {
    final sorted = [...values]..sort();
    return sorted[math.min(sorted.length - 1, (q * sorted.length).floor())];
  }
}
