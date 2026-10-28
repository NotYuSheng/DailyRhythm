import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/services/database/repositories/catalog_repository.dart';
import '../../domain/calorie_estimator.dart';
import '../models/meal_entry.dart';
import '../services/calorie_lookup.dart';

/// Where calorie lookups go; replaced in tests.
final calorieLookupProvider = Provider<CalorieLookup>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return OpenFoodFactsLookup(client);
});

/// The built-in table of common foods' calories, for estimates; empty if
/// it can't be read.
final referenceFoodsProvider = FutureProvider<List<ReferenceFood>>((ref) async {
  try {
    final json = jsonDecode(await rootBundle.loadString('assets/data/common_foods.json')) as List;
    return [for (final f in json) ReferenceFood.fromJson(f as Map<String, dynamic>)];
  } catch (_) {
    return const [];
  }
});

/// Calories per serving of each food that has them, by food id.
final foodCaloriesProvider = FutureProvider<Map<int, double>>((ref) {
  return CatalogRepository(ref.watch(databaseProvider)).foodCalories();
});

/// Health score categories the user set for foods, by food id.
final foodHealthTagsProvider = FutureProvider<Map<int, List<String>>>((ref) {
  return CatalogRepository(ref.watch(databaseProvider)).foodHealthTags();
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
