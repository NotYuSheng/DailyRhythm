import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../models/sleep_entry.dart';

/// Sleep entries provider for a specific date
final sleepEntriesProvider = FutureProvider.family<List<SleepEntry>, DateTime>((ref, date) async {
  final db = ref.watch(databaseProvider);
  return db.getSleepEntriesByDate(date);
});

/// Legacy provider for current day (for backward compatibility)
final todaySleepEntriesProvider = FutureProvider<List<SleepEntry>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getSleepEntriesByDate(DateTime.now());
});
