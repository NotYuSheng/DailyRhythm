import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/database/database_provider.dart';
import '../../health/data/models/health_metric.dart';
import '../../metrics/data/models/metric_data.dart';
import '../domain/profile.dart';
import 'profile_repository.dart';
import 'weight_repository.dart';

/// The profile, its weight the latest one logged (the profile's own when
/// none has been).
final profileProvider = FutureProvider<Profile>((ref) async {
  final profile = await ProfileRepository().load();
  final latest = await WeightRepository(ref.watch(databaseProvider)).latest();
  return latest == null ? profile : profile.copyWith(weightKg: latest.value);
});

/// Weights logged in a period, oldest first.
final weightsProvider = FutureProvider.autoDispose.family<List<HealthMetric>, DateRange>((ref, range) {
  return WeightRepository(ref.watch(databaseProvider)).inRange(range.start, range.end);
});
