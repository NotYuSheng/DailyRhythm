import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/database/database_provider.dart';
import 'learning_entry.dart';
import 'learning_repository.dart';

/// What was learnt on a day.
final learningProvider = FutureProvider.family<List<LearningEntry>, DateTime>((ref, day) {
  return LearningRepository(ref.watch(databaseProvider)).forDay(day);
});

/// Topics used so far, the most used first.
final learningTopicsProvider = FutureProvider<List<String>>((ref) {
  return LearningRepository(ref.watch(databaseProvider)).topics();
});
