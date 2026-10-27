import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/day_checkin.dart';
import '../../../shared/services/database/database_provider.dart';
import '../../../shared/services/database/repositories/checkin_repository.dart';
import '../../../shared/services/database/repositories/journal_repository.dart';
import '../../journal/data/models/journal_entry.dart';
import '../../tags/data/models/tag.dart';
import '../domain/garden_day.dart';
import '../domain/recap.dart';
import '../domain/year_overview.dart';
import 'garden_repository.dart';
import 'year_overview_repository.dart';

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

/// Recaps for every month from [start] to [end] (month starts), built
/// from one read of the logs and moments.
Future<List<MonthRecap>> _recaps(Ref ref, DateTime start, DateTime end) async {
  final db = ref.watch(databaseProvider);
  final last = DateTime(end.year, end.month + 1, 0);
  final logs = await GardenRepository(db).logsInRange(start, last);
  final moments = await JournalRepository(db).inRange(start, last);
  final activities = {for (final t in await db.getAllTags()) if (t.kind == TagKind.activity) t.name};
  return [
    for (var m = start; !m.isAfter(end); m = DateTime(m.year, m.month + 1))
      MonthRecap.from(
        month: m,
        logs: [for (final l in logs) if (l.date.year == m.year && l.date.month == m.month) l],
        moments: [for (final j in moments) if (j.date.year == m.year && j.date.month == m.month) j],
        activityTags: activities,
      ),
  ];
}

/// The month in review for the month containing the given date.
final monthRecapProvider = FutureProvider.autoDispose.family<MonthRecap, DateTime>((ref, month) async {
  final start = DateTime(month.year, month.month);
  return (await _recaps(ref, start, start)).single;
});

/// The year at a glance: every day, mood and sleep by month, tags that
/// stood out and a row per month.
final yearOverviewProvider = FutureProvider.autoDispose.family<YearOverview, int>((ref, year) {
  return YearOverviewRepository(ref.watch(databaseProvider)).load(year);
});

/// The years with anything logged, oldest first.
final loggedYearsProvider = FutureProvider.autoDispose<List<int>>((ref) {
  return YearOverviewRepository(ref.watch(databaseProvider)).years();
});

/// Refreshes everything the garden shows after a change on [day].
void invalidateGardenDay(WidgetRef ref, DateTime day) {
  // Plants of other days can change too: the next day's sleep, and which
  // tags count as routine.
  ref.invalidate(gardenDayProvider);
  ref.invalidate(gardenMonthProvider);
  ref.invalidate(monthRecapProvider);
  ref.invalidate(yearOverviewProvider);
  ref.invalidate(checkinProvider(day));
  ref.invalidate(momentsProvider(day));
}
