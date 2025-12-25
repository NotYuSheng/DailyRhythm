import 'dart:math';
import '../models/metric_data.dart';
import '../../../exercise/data/models/exercise_entry.dart';
import '../../../tags/data/models/tag.dart';
import '../../../../shared/services/database/database_service.dart';

/// Service for calculating metrics and statistics
class MetricsService {
  final DatabaseService _db;

  MetricsService(this._db);

  // ==================== Sleep Metrics ====================

  Future<SleepMetrics> calculateSleepMetrics(DateRange range, {DateRange? previousRange}) async {
    final entries = await _db.getSleepEntriesInRange(range.start, range.end);

    // Calculate daily data points
    final dailyData = <DailyDataPoint>[];
    for (final entry in entries) {
      final hours = entry.totalHours ?? entry.calculatedHours;
      dailyData.add(DailyDataPoint(date: entry.date, value: hours));
    }

    // Calculate average
    final averageHours = entries.isEmpty
        ? 0.0
        : entries.fold<double>(0.0, (sum, entry) => sum + (entry.totalHours ?? entry.calculatedHours)) / entries.length;

    // Calculate consistency (standard deviation)
    double consistency = 0.0;
    if (entries.length > 1) {
      final mean = averageHours;
      final variance = entries.fold<double>(0.0, (sum, entry) {
        final hours = entry.totalHours ?? entry.calculatedHours;
        return sum + pow(hours - mean, 2);
      }) / entries.length;
      consistency = sqrt(variance);
    }

    // Calculate previous period average if provided
    double? previousAverageHours;
    if (previousRange != null) {
      final previousEntries = await _db.getSleepEntriesInRange(previousRange.start, previousRange.end);
      if (previousEntries.isNotEmpty) {
        previousAverageHours = previousEntries.fold<double>(
          0.0,
          (sum, entry) => sum + (entry.totalHours ?? entry.calculatedHours),
        ) / previousEntries.length;
      }
    }

    return SleepMetrics(
      averageHours: averageHours,
      consistency: consistency,
      dailyData: dailyData,
      previousAverageHours: previousAverageHours,
    );
  }

  // ==================== Mood Metrics ====================

  Future<MoodMetrics> calculateMoodMetrics(DateRange range, {DateRange? previousRange}) async {
    final entries = await _db.getMoodEntriesInRange(range.start, range.end);

    // Calculate daily data points
    final dailyData = <DailyDataPoint>[];
    for (final entry in entries) {
      dailyData.add(DailyDataPoint(date: entry.date, value: entry.moodLevel.toDouble()));
    }

    // Calculate average mood
    final averageMood = entries.isEmpty
        ? 0.0
        : entries.fold<double>(0.0, (sum, entry) => sum + entry.moodLevel) / entries.length;

    // Calculate mood distribution
    final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final entry in entries) {
      distribution[entry.moodLevel] = (distribution[entry.moodLevel] ?? 0) + 1;
    }

    // Calculate previous period average if provided
    double? previousAverageMood;
    if (previousRange != null) {
      final previousEntries = await _db.getMoodEntriesInRange(previousRange.start, previousRange.end);
      if (previousEntries.isNotEmpty) {
        previousAverageMood = previousEntries.fold<double>(
          0.0,
          (sum, entry) => sum + entry.moodLevel,
        ) / previousEntries.length;
      }
    }

    return MoodMetrics(
      averageMood: averageMood,
      distribution: distribution,
      dailyData: dailyData,
      previousAverageMood: previousAverageMood,
    );
  }

  // ==================== Exercise Metrics ====================

  Future<ExerciseMetrics> calculateExerciseMetrics(DateRange range, {DateRange? previousRange}) async {
    final entries = await _db.getExerciseEntriesInRange(range.start, range.end);

    final totalExercises = entries.length;

    // Calculate running distance
    final totalRunningDistance = entries
        .where((e) => e.type == ExerciseType.run && e.distance != null)
        .fold<double>(0.0, (sum, entry) => sum + entry.distance!);

    // Calculate weight lifted (sets * reps * weight)
    final totalWeightLifted = entries
        .where((e) => e.type == ExerciseType.weightLifting && e.weight != null && e.sets != null && e.reps != null)
        .fold<double>(0.0, (sum, entry) => sum + (entry.sets! * entry.reps! * entry.weight!));

    // Calculate previous period if provided
    int? previousTotalExercises;
    if (previousRange != null) {
      final previousEntries = await _db.getExerciseEntriesInRange(previousRange.start, previousRange.end);
      previousTotalExercises = previousEntries.length;
    }

    return ExerciseMetrics(
      totalExercises: totalExercises,
      totalRunningDistance: totalRunningDistance,
      totalWeightLifted: totalWeightLifted,
      previousTotalExercises: previousTotalExercises,
    );
  }

  // ==================== Activity Metrics ====================

  Future<ActivityMetrics> calculateActivityMetrics(DateRange range, {DateRange? previousRange}) async {
    final entries = await _db.getActivityEntriesInRange(range.start, range.end);
    final allTags = await _db.getAllTags();

    final totalActivities = entries.length;

    // Count tag frequencies
    final tagCounts = <int, int>{};
    for (final entry in entries) {
      tagCounts[entry.tagId] = (tagCounts[entry.tagId] ?? 0) + 1;
    }

    // Create top activities list
    final topActivities = <ActivityFrequency>[];
    for (final tagEntry in tagCounts.entries) {
      final tag = allTags.firstWhere((t) => t.id == tagEntry.key, orElse: () => Tag(
        name: 'Unknown',
        emoji: 'question_circle',
        category: 'General',
      ));

      final count = tagEntry.value;
      final percentage = totalActivities > 0 ? (count / totalActivities) * 100 : 0.0;

      topActivities.add(ActivityFrequency(
        tagName: tag.name,
        emoji: tag.emoji,
        count: count,
        percentage: percentage,
      ));
    }

    // Sort by count descending
    topActivities.sort((a, b) => b.count.compareTo(a.count));

    // Calculate previous period if provided
    int? previousTotalActivities;
    if (previousRange != null) {
      final previousEntries = await _db.getActivityEntriesInRange(previousRange.start, previousRange.end);
      previousTotalActivities = previousEntries.length;
    }

    return ActivityMetrics(
      totalActivities: totalActivities,
      topActivities: topActivities,
      previousTotalActivities: previousTotalActivities,
    );
  }

  // ==================== Insights Generation ====================

  Future<List<MetricsInsight>> generateInsights(DateRange range) async {
    final insights = <MetricsInsight>[];

    // Get all metrics
    final previousRange = _calculatePreviousRange(range);
    final sleepMetrics = await calculateSleepMetrics(range, previousRange: previousRange);
    final moodMetrics = await calculateMoodMetrics(range, previousRange: previousRange);
    final exerciseMetrics = await calculateExerciseMetrics(range, previousRange: previousRange);

    // Sleep insights
    if (sleepMetrics.averageHours > 0) {
      if (sleepMetrics.previousAverageHours != null) {
        final diff = sleepMetrics.averageHours - sleepMetrics.previousAverageHours!;
        if (diff.abs() > 0.5) {
          final direction = diff > 0 ? 'more' : 'less';
          final hours = diff.abs().toStringAsFixed(1);
          insights.add(MetricsInsight(
            text: 'You slept $hours hours $direction this period compared to the previous period',
            type: diff > 0 ? InsightType.positive : InsightType.negative,
          ));
        }
      }

      if (sleepMetrics.consistency < 1.0) {
        insights.add(MetricsInsight(
          text: 'Great sleep consistency! Your sleep hours are very regular',
          type: InsightType.positive,
        ));
      } else if (sleepMetrics.consistency > 2.0) {
        insights.add(MetricsInsight(
          text: 'Your sleep schedule varies significantly. Try maintaining a consistent sleep routine',
          type: InsightType.negative,
        ));
      }
    }

    // Mood insights
    if (moodMetrics.averageMood > 0) {
      if (moodMetrics.averageMood >= 4.0) {
        insights.add(MetricsInsight(
          text: 'Your mood has been consistently positive! Keep up the great work',
          type: InsightType.positive,
        ));
      } else if (moodMetrics.averageMood < 3.0) {
        insights.add(MetricsInsight(
          text: 'Your mood could use a boost. Consider activities that bring you joy',
          type: InsightType.negative,
        ));
      }

      if (moodMetrics.previousAverageMood != null) {
        final diff = moodMetrics.averageMood - moodMetrics.previousAverageMood!;
        if (diff.abs() > 0.5) {
          final direction = diff > 0 ? 'improved' : 'decreased';
          insights.add(MetricsInsight(
            text: 'Your mood has $direction compared to the previous period',
            type: diff > 0 ? InsightType.positive : InsightType.negative,
          ));
        }
      }
    }

    // Exercise insights
    if (exerciseMetrics.totalExercises > 0) {
      if (exerciseMetrics.previousTotalExercises != null) {
        final diff = exerciseMetrics.totalExercises - exerciseMetrics.previousTotalExercises!;
        if (diff > 0) {
          insights.add(MetricsInsight(
            text: 'You exercised $diff more times this period. Great progress!',
            type: InsightType.positive,
          ));
        }
      }

      if (exerciseMetrics.totalRunningDistance > 0) {
        insights.add(MetricsInsight(
          text: 'You ran ${exerciseMetrics.totalRunningDistance.toStringAsFixed(1)}km this period',
          type: InsightType.neutral,
        ));
      }
    } else if (range.daysCount >= 7) {
      insights.add(MetricsInsight(
        text: 'No exercises logged this period. Physical activity can improve mood and sleep',
        type: InsightType.neutral,
      ));
    }

    // Correlation insight (basic)
    if (sleepMetrics.averageHours >= 7.0 && moodMetrics.averageMood >= 4.0) {
      insights.add(MetricsInsight(
        text: 'Good sleep and positive mood are aligned. Keep maintaining this balance!',
        type: InsightType.correlation,
      ));
    }

    return insights;
  }

  DateRange _calculatePreviousRange(DateRange current) {
    final duration = current.end.difference(current.start);
    final previousEnd = current.start.subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(duration);
    return DateRange(
      start: previousStart,
      end: previousEnd,
      label: 'Previous Period',
    );
  }

  // ==================== Helper Methods ====================

  TrendDirection calculateTrend(double current, double? previous) {
    if (previous == null || current == 0) return TrendDirection.neutral;

    final diff = current - previous;
    final percentChange = (diff / previous).abs();

    if (percentChange < 0.05) return TrendDirection.neutral; // Less than 5% change
    if (diff > 0) return TrendDirection.up;
    return TrendDirection.down;
  }
}
