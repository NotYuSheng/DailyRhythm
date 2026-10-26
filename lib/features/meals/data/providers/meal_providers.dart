import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/services/database/repositories/catalog_repository.dart';
import '../models/meal_entry.dart';
import '../services/calorie_lookup.dart';

/// Where calorie lookups go; replaced in tests.
final calorieLookupProvider = Provider<CalorieLookup>((ref) => OpenFoodFactsLookup());

/// Calories per serving of each food that has them, by food id.
final foodCaloriesProvider = FutureProvider<Map<int, double>>((ref) {
  return CatalogRepository(ref.watch(databaseProvider)).foodCalories();
});

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
