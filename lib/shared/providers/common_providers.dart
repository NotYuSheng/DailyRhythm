import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/database_provider.dart';
import '../models/mood_entry.dart';
import '../models/task_entry.dart';

/// Mood entry provider for a specific date (single mood per day)
final moodEntryProvider = FutureProvider.family<MoodEntry?, DateTime>((ref, date) async {
  final db = ref.watch(databaseProvider);
  return db.getMoodEntryByDate(date);
});

/// Task entries provider for a specific date
final taskEntriesProvider = FutureProvider.family<List<TaskEntry>, DateTime>((ref, date) async {
  final db = ref.watch(databaseProvider);
  return db.getTaskEntriesByDate(date);
});

/// Legacy provider for current day mood (for backward compatibility)
final todayMoodEntryProvider = FutureProvider<MoodEntry?>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getMoodEntryByDate(DateTime.now());
});

/// Provider to refresh/invalidate all current day data
final refreshTodayDataProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(todayMoodEntryProvider);
  };
});
