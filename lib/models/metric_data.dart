/// Data models for metrics and statistics
class MetricData {
  final double value;
  final double? previousValue;
  final String label;
  final TrendDirection trend;

  MetricData({
    required this.value,
    this.previousValue,
    required this.label,
    required this.trend,
  });

  double get trendPercentage {
    if (previousValue == null || previousValue == 0) return 0.0;
    return ((value - previousValue!) / previousValue!) * 100;
  }
}

enum TrendDirection {
  up,
  down,
  neutral,
}

class DateRange {
  final DateTime start;
  final DateTime end;
  final String label;

  DateRange({
    required this.start,
    required this.end,
    required this.label,
  });

  factory DateRange.last7Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    return DateRange(
      start: start,
      end: today,
      label: 'Last 7 Days',
    );
  }

  factory DateRange.last30Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 29));
    return DateRange(
      start: start,
      end: today,
      label: 'Last 30 Days',
    );
  }

  factory DateRange.thisMonth() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(now.year, now.month, 1);
    return DateRange(
      start: start,
      end: today,
      label: 'This Month',
    );
  }

  factory DateRange.thisYear() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(now.year, 1, 1);
    return DateRange(
      start: start,
      end: today,
      label: 'This Year',
    );
  }

  factory DateRange.allTime() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(2020, 1, 1); // App inception date
    return DateRange(
      start: start,
      end: today,
      label: 'All Time',
    );
  }

  int get daysCount => end.difference(start).inDays + 1;
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
  final int count;
  final double percentage;

  ActivityFrequency({
    required this.tagName,
    required this.emoji,
    required this.count,
    required this.percentage,
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
