import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../../../shared/utils/date_utils.dart';
import 'metric_data.dart';

/// How far an overview looks, and so how it groups days: a week by day, a
/// month by week, a year by month, all time by year.
enum OverviewScale {
  week('day', 'Day by day', 'night by night'),
  month('week', 'Week by week', 'week by week'),
  year('month', 'Month by month', 'month by month'),
  all('year', 'Year by year', 'year by year');

  const OverviewScale(this.groupNoun, this.tableTitle, this.sleepTitle);

  /// What one group is: "week" for a month.
  final String groupNoun;
  final String tableTitle;
  final String sleepTitle;
}

/// What one day held, or the average of a week's days in the all-time grid.
class DayValues {
  DayValues(this.date);

  /// The days' averages, for one cell standing for several days.
  factory DayValues.mean(DateTime date, List<DayValues> days) {
    double? mean(Iterable<num?> values) {
      final known = [for (final v in values) ?v];
      return known.isEmpty ? null : known.reduce((a, b) => a + b) / known.length;
    }

    return DayValues(date)
      ..sleepHours = mean(days.map((d) => d.sleepHours))
      ..steps = mean(days.map((d) => d.steps))
      ..kcal = mean(days.map((d) => d.kcal))
      ..mood = mean(days.map((d) => d.mood))?.round()
      ..energy = mean(days.map((d) => d.energy))?.round()
      ..effort = mean(days.map((d) => d.effort))?.round()
      ..diet = mean(days.map((d) => d.diet));
  }

  final DateTime date;
  double? sleepHours;
  double? steps;
  double? kcal;
  int? mood;
  int? energy;

  /// How hard the day's exercise was, 1–5; null without any.
  int? effort;

  /// How healthy the day's food was, 1–5; null without meals.
  double? diet;
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

/// A stretch of days the overview groups by: a day, week, month or year.
class OverviewGroup {
  const OverviewGroup({required this.start, required this.end, required this.label, required this.short, required this.name});

  final DateTime start;
  final DateTime end;

  /// For the table: "Mar", "6–12", "Mon", "2024".
  final String label;

  /// For narrow bars: "M" for March.
  final String short;

  /// Read out by screen readers: "March", "6–12 October".
  final String name;
}

/// A group's usual sleep: the median bedtime and wake time, the middle half
/// of each, and the average length.
class GroupSleep {
  const GroupSleep({
    required this.group,
    required this.bed,
    required this.wake,
    required this.bedLow,
    required this.bedHigh,
    required this.wakeLow,
    required this.wakeHigh,
    required this.hours,
  });

  final OverviewGroup group;
  final double bed;
  final double wake;
  final double bedLow;
  final double bedHigh;
  final double wakeLow;
  final double wakeHigh;
  final double? hours;
}

/// A group's averages and spending, for the table.
class GroupRow {
  const GroupRow({
    required this.group,
    required this.days,
    this.sleep,
    this.steps,
    this.kcal,
    this.effort,
    this.diet,
    required this.food,
    required this.events,
  });

  final OverviewGroup group;

  /// Days logged.
  final int days;
  final double? sleep;
  final double? steps;
  final double? kcal;

  /// Average effort (1–5) on the days with exercise.
  final double? effort;

  /// Average health score (1–5) on the days with meals.
  final double? diet;
  final double food;
  final double events;
}

/// A tag the user logs only some days, and which days.
class RareTag {
  const RareTag(this.name, this.days);

  final String name;
  final List<DateTime> days;
}

/// One row of the "every day" grid; a null cell is outside the period.
class PixelRow {
  const PixelRow(this.label, this.cells);

  final String label;
  final List<DayValues?> cells;
}

/// A period at a glance: every day coloured by a measure, mood and sleep by
/// group, the tags that stood out, and a row per group. Built from plain
/// inputs so it can be tested without a database.
class PeriodOverview {
  PeriodOverview._({
    required this.scale,
    required this.start,
    required this.end,
    required this.groups,
    required this.grid,
    required this.columnLabels,
    required this.loggedDays,
    required this.moodByGroup,
    required this.sleepByGroup,
    required this.rareTags,
    required this.everydayTags,
    required this.rows,
    required this.averageSteps,
  });

  final OverviewScale scale;
  final DateTime start;

  /// The last day shown: the period's end, or today while it's going.
  final DateTime end;
  final List<OverviewGroup> groups;

  /// Year: a row per month, a cell per day. Month: calendar weeks. Week: one
  /// row. All time: a row per year, a cell per week.
  final List<PixelRow> grid;

  /// Weekday letters over a week or month grid; empty otherwise.
  final List<String> columnLabels;
  final int loggedDays;

  /// Days per mood (1–5) for each group.
  final List<List<int>> moodByGroup;
  final List<GroupSleep> sleepByGroup;

  /// Tags on fewer than [ActivityMetrics.everydayShare] of logged days, most
  /// used first.
  final List<RareTag> rareTags;

  /// Tags on most days, left out of [rareTags] and named instead.
  final List<String> everydayTags;
  final List<GroupRow> rows;

  static const maxRareTags = 5;

  /// Average daily steps over the period, for the calorie range.
  final double? averageSteps;

  /// Anything to show: logged days, or watch data alone.
  bool get hasData => loggedDays > 0 || rows.isNotEmpty;

  /// Grid cells with a value for [levelOf].
  int cellsWith(int? Function(DayValues) levelOf) => grid.fold(0, (n, r) => n + r.cells.where((c) => c != null && levelOf(c) != null).length);

  /// The groups for [scale] from [start] to [end].
  static List<OverviewGroup> groupsFor(OverviewScale scale, DateTime start, DateTime end) {
    final out = <OverviewGroup>[];
    var s = start;
    while (!s.isAfter(end)) {
      final last = switch (scale) {
        OverviewScale.week => s,
        OverviewScale.month => DateTime(s.year, s.month, s.day + 7 - s.weekday),
        OverviewScale.year => DateTime(s.year, s.month + 1, 0),
        OverviewScale.all => DateTime(s.year, 12, 31),
      };
      final e = last.isAfter(end) ? end : last;
      out.add(switch (scale) {
        OverviewScale.week => OverviewGroup(start: s, end: e, label: DateFormat('E').format(s), short: DateFormat('E').format(s), name: DateFormat('EEEE d MMMM').format(s)),
        OverviewScale.month => OverviewGroup(
            start: s,
            end: e,
            label: s == e ? '${s.day}' : '${s.day}–${e.day}',
            short: s == e ? '${s.day}' : '${s.day}–${e.day}',
            name: '${s == e ? '${s.day}' : '${s.day} to ${e.day}'} ${DateFormat('MMMM').format(s)}',
          ),
        OverviewScale.year => OverviewGroup(start: s, end: e, label: DateFormat('MMM').format(s), short: DateFormat('MMMMM').format(s), name: DateFormat('MMMM').format(s)),
        OverviewScale.all => OverviewGroup(start: s, end: e, label: '${s.year}', short: "'${'${s.year}'.substring(2)}", name: '${s.year}'),
      });
      s = DateTime(e.year, e.month, e.day + 1);
    }
    return out;
  }

  factory PeriodOverview.build({
    required OverviewScale scale,
    required DateTime start,
    required DateTime end,
    required DateTime today,
    required Set<DateTime> logged,
    required Map<DateTime, double> sleepHours,
    required Map<DateTime, double> steps,
    required Map<DateTime, double> kcal,
    required Map<DateTime, int> moods,
    required Map<DateTime, int> energy,
    Map<DateTime, int> effort = const {},
    Map<DateTime, double> diet = const {},
    required List<NightSpan> nights,
    required Map<String, Set<DateTime>> tagDays,
    required Map<DateTime, double> foodSpend,
    required Map<DateTime, double> eventSpend,
  }) {
    final first = dayOf(start);
    final last = [dayOf(end), dayOf(today)].reduce((a, b) => a.isBefore(b) ? a : b);
    final groups = groupsFor(scale, first, last);
    final days = <DateTime, DayValues>{
      for (var d = first; !d.isAfter(last); d = DateTime(d.year, d.month, d.day + 1))
        d: DayValues(d)
          ..sleepHours = sleepHours[d]
          ..steps = steps[d]
          ..kcal = kcal[d]
          ..mood = moods[d]
          ..energy = energy[d]
          ..effort = effort[d]
          ..diet = diet[d],
    };
    bool inRange(DateTime d) => !d.isBefore(first) && !d.isAfter(last);
    final inPeriod = {for (final d in logged) if (inRange(d)) d};

    // Which group each day falls in, for one pass over each map.
    final groupOf = <DateTime, int>{};
    for (final (i, g) in groups.indexed) {
      for (var d = g.start; !d.isAfter(g.end); d = DateTime(d.year, d.month, d.day + 1)) {
        groupOf[d] = i;
      }
    }
    List<List<double>> byGroup(Map<DateTime, double> values) {
      final out = [for (final _ in groups) <double>[]];
      for (final MapEntry(key: day, value: v) in values.entries) {
        if (groupOf[day] case final i?) out[i].add(v);
      }
      return out;
    }

    final moodByGroup = [for (final _ in groups) List.filled(5, 0)];
    for (final MapEntry(key: day, value: level) in moods.entries) {
      if (groupOf[day] case final i? when level >= 1 && level <= 5) moodByGroup[i][level - 1]++;
    }

    final sleepGroups = byGroup(sleepHours);
    final nightsByGroup = [for (final _ in groups) <NightSpan>[]];
    for (final n in nights) {
      if (groupOf[n.day] case final i?) nightsByGroup[i].add(n);
    }
    final sleepByGroup = <GroupSleep>[
      for (final (i, group) in groups.indexed)
        if (nightsByGroup[i].isNotEmpty)
          () {
            final beds = [for (final n in nightsByGroup[i]) n.bed];
            final wakes = [for (final n in nightsByGroup[i]) n.wake];
            return GroupSleep(
              group: group,
              bed: _quantile(beds, 0.5),
              wake: _quantile(wakes, 0.5),
              bedLow: _quantile(beds, 0.25),
              bedHigh: _quantile(beds, 0.75),
              wakeLow: _quantile(wakes, 0.25),
              wakeHigh: _quantile(wakes, 0.75),
              hours: _mean(sleepGroups[i]),
            );
          }(),
    ];

    final everyday = <String>[];
    final rare = <RareTag>[];
    for (final MapEntry(key: name, value: dates) in tagDays.entries) {
      final used = [for (final d in dates) if (inPeriod.contains(d)) d]..sort();
      if (used.isEmpty) continue;
      // The same rule as Metrics' "Most days".
      if (inPeriod.length >= ActivityMetrics.everydayMinDays && used.length >= inPeriod.length * ActivityMetrics.everydayShare) {
        everyday.add(name);
      } else {
        rare.add(RareTag(name, used));
      }
    }
    rare.sort((a, b) => b.days.length.compareTo(a.days.length));
    everyday.sort();

    final stepGroups = byGroup(steps);
    final kcalGroups = byGroup(kcal);
    final dietGroups = byGroup(diet);
    final effortGroups = byGroup({for (final MapEntry(key: d, value: v) in effort.entries) d: v.toDouble()});
    final foodGroups = byGroup(foodSpend);
    final eventGroups = byGroup(eventSpend);
    final loggedPerGroup = List.filled(groups.length, 0);
    for (final d in inPeriod) {
      if (groupOf[d] case final i?) loggedPerGroup[i]++;
    }
    final rows = [
      for (final (i, group) in groups.indexed)
        // Groups with logs, or watch data alone.
        if (loggedPerGroup[i] > 0 || sleepGroups[i].isNotEmpty || stepGroups[i].isNotEmpty)
          GroupRow(
            group: group,
            days: loggedPerGroup[i],
            sleep: _mean(sleepGroups[i]),
            steps: _mean(stepGroups[i]),
            kcal: _mean(kcalGroups[i]),
            effort: _mean(effortGroups[i]),
            diet: _mean(dietGroups[i]),
            food: foodGroups[i].fold(0.0, (s, v) => s + v),
            events: eventGroups[i].fold(0.0, (s, v) => s + v),
          ),
    ];

    return PeriodOverview._(
      scale: scale,
      start: first,
      end: last,
      groups: groups,
      grid: _grid(scale, first, last, days),
      columnLabels: scale == OverviewScale.week || scale == OverviewScale.month ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S'] : const [],
      loggedDays: inPeriod.length,
      moodByGroup: moodByGroup,
      sleepByGroup: sleepByGroup,
      rareTags: rare.take(maxRareTags).toList(),
      everydayTags: everyday,
      rows: rows,
      averageSteps: _mean([for (final MapEntry(key: d, value: v) in steps.entries) if (inRange(d)) v]),
    );
  }

  static List<PixelRow> _grid(OverviewScale scale, DateTime first, DateTime last, Map<DateTime, DayValues> days) {
    switch (scale) {
      case OverviewScale.week:
        return [PixelRow('', [for (var i = 0; i < 7; i++) days[DateTime(first.year, first.month, first.day + i)]])];
      case OverviewScale.month:
        final rows = <PixelRow>[];
        var monday = DateTime(first.year, first.month, first.day - (first.weekday - 1));
        while (!monday.isAfter(last)) {
          rows.add(PixelRow('', [for (var i = 0; i < 7; i++) days[DateTime(monday.year, monday.month, monday.day + i)]]));
          monday = DateTime(monday.year, monday.month, monday.day + 7);
        }
        return rows;
      case OverviewScale.year:
        return [
          for (var m = 1; m <= 12; m++)
            PixelRow(DateFormat('MMMMM').format(DateTime(first.year, m)), [
              // DateTime(y, 2, 31) is in March: those cells stay empty.
              for (var d = 1; d <= 31; d++) DateTime(first.year, m, d).month == m ? days[DateTime(first.year, m, d)] : null,
            ]),
        ];
      case OverviewScale.all:
        // A cell per week of each year, the week's days averaged.
        return [
          for (var y = first.year; y <= last.year; y++)
            PixelRow("'${'$y'.substring(2)}", [
              for (var w = 0; w < 53; w++)
                () {
                  final week = [
                    for (var i = 0; i < 7; i++) ?days[DateTime(y, 1, 1 + w * 7 + i)],
                  ].where((d) => d.date.year == y).toList();
                  return week.isEmpty ? null : DayValues.mean(week.first.date, week);
                }(),
            ]),
        ];
    }
  }

  static double? _mean(List<double> values) => values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

  static double _quantile(List<double> values, double q) {
    final sorted = [...values]..sort();
    return sorted[math.min(sorted.length - 1, (q * sorted.length).floor())];
  }
}
