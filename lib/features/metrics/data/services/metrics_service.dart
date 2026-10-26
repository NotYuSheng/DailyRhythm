import 'dart:math';
import '../models/metric_data.dart';
import '../../../exercise/data/models/exercise_entry.dart';
import '../../../sleep/data/models/sleep_entry.dart';
import '../../../tags/data/models/tag.dart';
import '../../../../shared/models/mood_entry.dart';
import '../../../../shared/services/database/database_service.dart';
import '../../../../shared/utils/date_utils.dart';

/// Service for calculating metrics and statistics
class MetricsService {
  final DatabaseService _db;

  MetricsService(this._db);

  // ==================== Sleep Metrics ====================

  Future<SleepMetrics> calculateSleepMetrics(DateRange range, {DateRange? previousRange}) async {
    // Only days with a computed total count. Without the previous night's
    // bedtime a day's sleep is unknown, not zero or same-day bed-to-wake.
    final entries = (await _db.getSleepEntriesInRange(range.start, range.end))
        .where((e) => e.totalHours != null)
        .toList();

    // Calculate daily data points
    final dailyData = <DailyDataPoint>[];
    for (final entry in entries) {
      dailyData.add(DailyDataPoint(date: entry.date, value: entry.totalHours!));
    }

    // Calculate average
    final averageHours = entries.isEmpty
        ? 0.0
        : entries.fold<double>(0.0, (sum, entry) => sum + entry.totalHours!) / entries.length;

    // Calculate consistency (standard deviation)
    double consistency = 0.0;
    if (entries.length > 1) {
      final mean = averageHours;
      final variance = entries.fold<double>(0.0, (sum, entry) {
        return sum + pow(entry.totalHours! - mean, 2);
      }) / entries.length;
      consistency = sqrt(variance);
    }

    // Calculate previous period average if provided
    double? previousAverageHours;
    if (previousRange != null) {
      final previousEntries = (await _db.getSleepEntriesInRange(previousRange.start, previousRange.end))
          .where((e) => e.totalHours != null)
          .toList();
      if (previousEntries.isNotEmpty) {
        previousAverageHours = previousEntries.fold<double>(
          0.0,
          (sum, entry) => sum + entry.totalHours!,
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

    // Days per activity tag (food sources and symptoms aren't activities),
    // as a share of the days with any activity.
    final kinds = {for (final t in allTags) t.id: t};
    final tagDays = <int, Set<DateTime>>{};
    for (final entry in entries) {
      if (kinds[entry.tagId]?.knownKind != TagKind.activity) continue;
      (tagDays[entry.tagId] ??= {}).add(dayOf(entry.date));
    }
    final tagged = {for (final days in tagDays.values) ...days};
    final totalActivities = tagDays.values.fold(0, (sum, days) => sum + days.length);

    final topActivities = <ActivityFrequency>[];
    for (final MapEntry(key: id, value: days) in tagDays.entries) {
      final tag = kinds[id]!;
      final share = days.length / tagged.length;
      topActivities.add(ActivityFrequency(
        tagName: tag.name,
        emoji: tag.emoji,
        count: days.length,
        percentage: share * 100,
        everyday: tagged.length >= ActivityMetrics.everydayMinDays && share >= ActivityMetrics.everydayShare,
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

  /// Fewest logged days a period needs before it is summarised or compared.
  /// Below this a difference is more likely noise than a pattern.
  static const int minDaysForInsight = 5;

  /// Describes the period's data as neutral observations.
  ///
  /// Insights state what was logged and how it compares with the previous
  /// period of the same length. They never give health advice or imply
  /// cause and effect, and periods with too little data are skipped.
  Future<List<MetricsInsight>> generateInsights(DateRange range) async {
    final insights = <MetricsInsight>[];

    // All time has nothing before it to compare with.
    final previousRange = range.isAllTime ? null : _calculatePreviousRange(range);
    // One after another: sqflite has one connection, so running these
    // together gains nothing.
    final sleepMetrics = await calculateSleepMetrics(range, previousRange: previousRange);
    final moodMetrics = await calculateMoodMetrics(range, previousRange: previousRange);
    final exerciseMetrics = await calculateExerciseMetrics(range, previousRange: previousRange);
    var previousSleep = const <SleepEntry>[];
    var previousMoods = const <MoodEntry>[];
    if (previousRange != null) {
      previousSleep = await _db.getSleepEntriesInRange(previousRange.start, previousRange.end);
      previousMoods = await _db.getMoodEntriesInRange(previousRange.start, previousRange.end);
    }
    final previousSleepDays = previousSleep.where((e) => e.totalHours != null).length;
    // Days, not entries: a day can have more than one mood.
    final previousMoodDays = {for (final e in previousMoods) dayOf(e.date)}.length;

    // Sleep
    final sleepDays = sleepMetrics.dailyData.length;
    if (sleepDays >= minDaysForInsight) {
      final average = sleepMetrics.averageHours.toStringAsFixed(1);
      final previous = sleepMetrics.previousAverageHours;
      if (previous != null && previousSleepDays >= minDaysForInsight &&
          (sleepMetrics.averageHours - previous).abs() >= 0.5) {
        final diff = sleepMetrics.averageHours - previous;
        insights.add(MetricsInsight(
          text: 'Average sleep was ${average}h over $sleepDays nights, '
              '${diff.abs().toStringAsFixed(1)}h ${diff > 0 ? 'more' : 'less'} than the previous period',
          type: diff > 0 ? InsightType.positive : InsightType.negative,
        ));
      } else {
        insights.add(MetricsInsight(
          text: 'Average sleep was ${average}h over $sleepDays nights',
          type: InsightType.neutral,
        ));
      }
      insights.add(MetricsInsight(
        text: 'Sleep length varied by about ±${sleepMetrics.consistency.toStringAsFixed(1)}h from night to night',
        type: InsightType.neutral,
      ));
    }

    // Mood
    final moodDays = {for (final d in moodMetrics.dailyData) dayOf(d.date)}.length;
    final previousMood = moodMetrics.previousAverageMood;
    if (moodDays >= minDaysForInsight && previousMood != null && previousMoodDays >= minDaysForInsight) {
      final diff = moodMetrics.averageMood - previousMood;
      if (diff.abs() >= 0.5) {
        insights.add(MetricsInsight(
          text: 'Average mood was ${moodMetrics.averageMood.toStringAsFixed(1)}/5 over $moodDays days, '
              '${diff > 0 ? 'up' : 'down'} from ${previousMood.toStringAsFixed(1)} in the previous period',
          type: diff > 0 ? InsightType.positive : InsightType.negative,
        ));
      }
    }

    // Exercise
    final previousExercises = exerciseMetrics.previousTotalExercises;
    if (exerciseMetrics.totalExercises > 0) {
      final sessions = exerciseMetrics.totalExercises;
      final comparison = previousExercises != null && previousExercises != sessions
          ? ' ($previousExercises in the previous period)'
          : '';
      insights.add(MetricsInsight(
        text: '$sessions exercise ${sessions == 1 ? 'entry' : 'entries'} logged$comparison',
        type: InsightType.neutral,
      ));
      if (exerciseMetrics.totalRunningDistance > 0) {
        insights.add(MetricsInsight(
          text: 'You ran ${exerciseMetrics.totalRunningDistance.toStringAsFixed(1)}km this period',
          type: InsightType.neutral,
        ));
      }
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
