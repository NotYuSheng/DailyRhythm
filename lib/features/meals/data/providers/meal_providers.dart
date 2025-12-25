import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../models/meal_entry.dart';

/// Meal entries provider for a specific date
final mealEntriesProvider = FutureProvider.family<List<MealEntry>, DateTime>((ref, date) async {
  final db = ref.watch(databaseProvider);
  return db.getMealEntriesByDate(date);
});

/// Legacy provider for current day (for backward compatibility)
final todayMealEntriesProvider = FutureProvider<List<MealEntry>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getMealEntriesByDate(DateTime.now());
});
