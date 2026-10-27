import 'dart:math' as math;

import '../../../shared/utils/date_utils.dart';

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

/// A night: when sleep started and ended, as hours after 20:00 the evening
/// before (00:30 is 4.5, 07:00 is 11), on the day it ended.
class NightSpan {
  const NightSpan(this.day, this.bed, this.wake);

  final DateTime day;
  final double bed;
  final double wake;

  /// Clock time as hours after 20:00, for the schedule chart's axis.
  static double fromClock(DateTime time) => (time.hour + time.minute / 60 - 20 + 24) % 24;
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

  static const everydayShare = 0.8;
  static const maxRareTags = 5;

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

    final moodByMonth = [
      for (var m = 1; m <= 12; m++)
        [for (var level = 1; level <= 5; level++) moods.entries.where((e) => e.key.year == year && e.key.month == m && e.value == level).length],
    ];

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
        hours: _mean([for (final e in sleepHours.entries) if (e.key.year == year && e.key.month == m) e.value]),
      ));
    }

    final everyday = <String>[];
    final rare = <RareTag>[];
    for (final MapEntry(key: name, value: dates) in tagDays.entries) {
      final used = [for (final d in dates) if (inYear.contains(d)) d]..sort();
      if (used.isEmpty) continue;
      if (inYear.length >= 14 && used.length >= inYear.length * everydayShare) {
        everyday.add(name);
      } else {
        rare.add(RareTag(name, used));
      }
    }
    rare.sort((a, b) => b.days.length.compareTo(a.days.length));
    everyday.sort();

    double sumIn(Map<DateTime, double> values, int m) =>
        values.entries.where((e) => e.key.year == year && e.key.month == m).fold(0.0, (s, e) => s + e.value);
    double? meanIn(Map<DateTime, double> values, int m) =>
        _mean([for (final e in values.entries) if (e.key.year == year && e.key.month == m) e.value]);
    final months = [
      for (var m = 1; m <= 12; m++)
        if (inYear.any((d) => d.month == m))
          MonthRow(
            month: m,
            days: inYear.where((d) => d.month == m).length,
            sleep: meanIn(sleepHours, m),
            steps: meanIn(steps, m),
            kcal: meanIn(kcal, m),
            food: sumIn(foodSpend, m),
            events: sumIn(eventSpend, m),
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
