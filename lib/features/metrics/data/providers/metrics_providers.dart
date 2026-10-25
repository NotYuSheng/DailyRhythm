import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/database/database_provider.dart';
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
