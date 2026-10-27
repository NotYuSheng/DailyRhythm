import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../services/day_ratings_service.dart';
import '../services/fun_facts_service.dart';
import '../services/metrics_service.dart';
import '../models/metric_data.dart';

/// Metrics service provider
final metricsServiceProvider = Provider<MetricsService>((ref) {
  final db = ref.watch(databaseProvider);
  return MetricsService(db);
});

/// Sleep metrics provider
final sleepMetricsProvider = FutureProvider.autoDispose.family<SleepMetrics, DateRange>((ref, range) async {
  final service = ref.watch(metricsServiceProvider);
  return service.calculateSleepMetrics(range);
});

/// Mood metrics provider
final moodMetricsProvider = FutureProvider.autoDispose.family<MoodMetrics, DateRange>((ref, range) async {
  final service = ref.watch(metricsServiceProvider);
  return service.calculateMoodMetrics(range);
});

/// Exercise metrics provider
final exerciseMetricsProvider = FutureProvider.autoDispose.family<ExerciseMetrics, DateRange>((ref, range) async {
  final service = ref.watch(metricsServiceProvider);
  return service.calculateExerciseMetrics(range);
});

/// Activity metrics provider
final activityMetricsProvider = FutureProvider.autoDispose.family<ActivityMetrics, DateRange>((ref, range) async {
  final service = ref.watch(metricsServiceProvider);
  return service.calculateActivityMetrics(range);
});

/// Insights provider
final metricsInsightsProvider = FutureProvider.autoDispose.family<List<MetricsInsight>, DateRange>((ref, range) async {
  final service = ref.watch(metricsServiceProvider);
  return service.generateInsights(range);
});

/// Fun facts provider
final funFactsProvider = FutureProvider.autoDispose.family<List<FunFact>, DateRange>((ref, range) async {
  return FunFactsService(ref.watch(databaseProvider)).factsFor(range);
});

/// The first day anything was logged, where stepping back stops.
final firstLoggedDayProvider = FutureProvider.autoDispose<DateTime?>((ref) {
  return ref.watch(databaseProvider).firstLoggedDay();
});

/// Mood, energy, stress and focus, tag comparisons and watch averages.
final dayRatingsProvider = FutureProvider.autoDispose.family<DayRatingsReport, DateRange>((ref, range) {
  return DayRatingsService(ref.watch(databaseProvider)).reportFor(range);
});

/// Recomputes every metric, for when entries may have changed since the
/// Metrics tab was last built (it stays alive when switching tabs).
void invalidateMetrics(WidgetRef ref) {
  for (final provider in [
    sleepMetricsProvider,
    moodMetricsProvider,
    exerciseMetricsProvider,
    activityMetricsProvider,
    metricsInsightsProvider,
    funFactsProvider,
    dayRatingsProvider,
    firstLoggedDayProvider,
  ]) {
    ref.invalidate(provider);
  }
}
