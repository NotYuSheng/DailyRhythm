import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/day_checkin.dart';
import '../../../shared/services/database/database_provider.dart';
import '../../../shared/services/database/repositories/checkin_repository.dart';
import '../../../shared/services/database/repositories/journal_repository.dart';
import '../../journal/data/models/journal_entry.dart';
import '../domain/garden_day.dart';
import 'garden_repository.dart';

/// Every day of the month containing the given date.
final gardenMonthProvider = FutureProvider.family<List<GardenDay>, DateTime>((ref, month) {
  final db = ref.watch(databaseProvider);
  return GardenRepository(db).daysInRange(DateTime(month.year, month.month), DateTime(month.year, month.month + 1, 0));
});

final gardenDayProvider = FutureProvider.family<GardenDay, DateTime>((ref, day) async {
  final db = ref.watch(databaseProvider);
  return (await GardenRepository(db).daysInRange(day, day)).single;
});

final checkinProvider = FutureProvider.family<DayCheckin?, DateTime>((ref, day) {
  return CheckinRepository(ref.watch(databaseProvider)).forDay(day);
});

final momentsProvider = FutureProvider.family<List<JournalEntry>, DateTime>((ref, day) {
  return JournalRepository(ref.watch(databaseProvider)).forDay(day);
});

/// Every day of the year, up to today for this year, for the year of gardens.
final gardenYearProvider = FutureProvider.autoDispose.family<List<GardenDay>, int>((ref, year) {
  final db = ref.watch(databaseProvider);
  final today = DateTime.now();
  return GardenRepository(db).daysInRange(DateTime(year), year == today.year ? today : DateTime(year, 12, 31));
});

/// Refreshes everything the garden shows after a change on [day].
void invalidateGardenDay(WidgetRef ref, DateTime day) {
  // Plants of other days can change too: the next day's sleep, and which
  // tags count as routine.
  ref.invalidate(gardenDayProvider);
  ref.invalidate(gardenMonthProvider);
  ref.invalidate(gardenYearProvider);
  ref.invalidate(checkinProvider(day));
  ref.invalidate(momentsProvider(day));
}
