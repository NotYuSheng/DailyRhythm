import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../models/exercise_entry.dart';

/// Exercise entries provider for a specific date
final exerciseEntriesProvider = FutureProvider.family<List<ExerciseEntry>, DateTime>((ref, date) async {
  final db = ref.watch(databaseProvider);
  return db.getExerciseEntriesByDate(date);
});
