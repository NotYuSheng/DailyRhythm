import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_service.dart';
import '../models/sleep_entry.dart';
import '../models/meal_entry.dart';
import '../models/mood_entry.dart';

// Database provider
final databaseProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

// Sleep entries provider for a specific date
final sleepEntriesProvider = FutureProvider.family<List<SleepEntry>, DateTime>((ref, date) async {
  final db = ref.watch(databaseProvider);
  return db.getSleepEntriesByDate(date);
});

// Meal entries provider for a specific date
final mealEntriesProvider = FutureProvider.family<List<MealEntry>, DateTime>((ref, date) async {
  final db = ref.watch(databaseProvider);
  return db.getMealEntriesByDate(date);
});

// Mood entry provider for a specific date (single mood per day)
final moodEntryProvider = FutureProvider.family<MoodEntry?, DateTime>((ref, date) async {
  final db = ref.watch(databaseProvider);
  return db.getMoodEntryByDate(date);
});

// Legacy providers for today (for backward compatibility)
final todaySleepEntriesProvider = FutureProvider<List<SleepEntry>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getSleepEntriesByDate(DateTime.now());
});

final todayMealEntriesProvider = FutureProvider<List<MealEntry>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getMealEntriesByDate(DateTime.now());
});

final todayMoodEntryProvider = FutureProvider<MoodEntry?>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getMoodEntryByDate(DateTime.now());
});

// Provider to refresh/invalidate all today data
final refreshTodayDataProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(todaySleepEntriesProvider);
    ref.invalidate(todayMealEntriesProvider);
    ref.invalidate(todayMoodEntryProvider);
  };
});
