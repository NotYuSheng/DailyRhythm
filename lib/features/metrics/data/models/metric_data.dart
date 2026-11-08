import 'package:intl/intl.dart';

import '../../../../shared/utils/date_utils.dart';

/// Data models for metrics and statistics
class DateRange {
  final DateTime start;
  final DateTime end;
  final String label;

  /// Everything logged: starts at the first entry, with nothing before it
  /// to compare against.
  final bool isAllTime;

  DateRange({
    required this.start,
    required this.end,
    required this.label,
    this.isAllTime = false,
  });

  /// The calendar week (Monday to Sunday) holding [day], up to [today].
  factory DateRange.week(DateTime day, {DateTime? today}) {
    final d = dayOf(day);
    final start = DateTime(d.year, d.month, d.day - (d.weekday - 1));
    final end = DateTime(start.year, start.month, start.day + 6);
    return DateRange._period(start, end, today, (s, e) => s.month == e.month
        ? '${s.day}–${e.day} ${DateFormat('MMM').format(s)}'
        : '${DateFormat('d MMM').format(s)} – ${DateFormat('d MMM').format(e)}');
  }

  /// The calendar month holding [day], up to [today].
  factory DateRange.month(DateTime day, {DateTime? today}) {
    final start = DateTime(day.year, day.month);
    return DateRange._period(start, DateTime(day.year, day.month + 1, 0), today, (s, _) => DateFormat('MMMM y').format(s));
  }

  /// The calendar year holding [day], up to [today].
  factory DateRange.year(DateTime day, {DateTime? today}) =>
      DateRange._period(DateTime(day.year), DateTime(day.year, 12, 31), today, (s, _) => '${s.year}');

  /// A whole calendar period, cut at today while it's still going.
  factory DateRange._period(DateTime start, DateTime end, DateTime? today, String Function(DateTime, DateTime) label) {
    final now = dayOf(today ?? DateTime.now());
    return DateRange(start: start, end: end.isAfter(now) ? now : end, label: label(start, end));
  }

  factory DateRange.allTime() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(2020, 1, 1); // App inception date
    return DateRange(
      start: start,
      end: today,
      label: 'All Time',
      isAllTime: true,
    );
  }

  int get daysCount => daysBetween(start, end) + 1;

  // Value equality so the range can be used as a provider family key.
  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end && other.label == label;

  @override
  int get hashCode => Object.hash(start, end, label);
}

class SleepMetrics {
  final double averageHours;
  final double consistency; // Standard deviation
  final List<DailyDataPoint> dailyData;
  final double? previousAverageHours;

  SleepMetrics({
    required this.averageHours,
    required this.consistency,
    required this.dailyData,
    this.previousAverageHours,
  });
}

class MoodMetrics {
  final double averageMood;
  final Map<int, int> distribution; // Mood level -> count
  final List<DailyDataPoint> dailyData;
  final double? previousAverageMood;

  MoodMetrics({
    required this.averageMood,
    required this.distribution,
    required this.dailyData,
    this.previousAverageMood,
  });
}

class ExerciseMetrics {
  final int totalExercises;
  final double totalRunningDistance;
  final double totalWeightLifted;
  final int? previousTotalExercises;

  ExerciseMetrics({
    required this.totalExercises,
    required this.totalRunningDistance,
    required this.totalWeightLifted,
    this.previousTotalExercises,
  });
}

class ActivityMetrics {
  /// Share of tagged days from which a tag counts as an everyday habit.
  static const everydayShare = 0.8;

  /// Tagged days needed before anything counts as everyday.
  static const everydayMinDays = 14;

  final int totalActivities;
  final List<ActivityFrequency> topActivities;
  final int? previousTotalActivities;

  ActivityMetrics({
    required this.totalActivities,
    required this.topActivities,
    this.previousTotalActivities,
  });
}

class ActivityFrequency {
  final String tagName;
  final String emoji;

  /// Days the tag was used.
  final int count;

  /// Share of the period's tagged days, 0–100.
  final double percentage;

  /// Used on so many days that it says little about any one of them.
  final bool everyday;

  ActivityFrequency({
    required this.tagName,
    required this.emoji,
    required this.count,
    required this.percentage,
    this.everyday = false,
  });
}

class DailyDataPoint {
  final DateTime date;
  final double value;

  DailyDataPoint({
    required this.date,
    required this.value,
  });
}

class MetricsInsight {
  final String text;
  final InsightType type;

  MetricsInsight({
    required this.text,
    required this.type,
  });
}

enum InsightType {
  positive,
  negative,
  neutral,
  correlation,
}
