import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_service.dart';
import '../models/sleep_entry.dart';
import '../models/meal_entry.dart';
import '../models/mood_entry.dart';

// Database provider
final databaseProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

// Sleep entries provider for today
final todaySleepEntriesProvider = FutureProvider<List<SleepEntry>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getSleepEntriesByDate(DateTime.now());
});

// Meal entries provider for today
final todayMealEntriesProvider = FutureProvider<List<MealEntry>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getMealEntriesByDate(DateTime.now());
});

// Mood entry provider for today (single mood per day)
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
