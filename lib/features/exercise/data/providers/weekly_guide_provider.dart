import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/services/database/repositories/health_repository.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../domain/weekly_guide.dart';

/// The weekly targets chosen in Settings, kept in preferences.
class WeeklyTargetsNotifier extends Notifier<WeeklyTargets> {
  static const _minutes = 'weekly_active_minutes', _strength = 'weekly_strength_days';

  @override
  WeeklyTargets build() {
    _load();
    return const WeeklyTargets();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_minutes), strength = prefs.getInt(_strength);
    if (minutes != null || strength != null) {
      state = WeeklyTargets(minutes: minutes ?? state.minutes, strengthDays: strength ?? state.strengthDays);
    }
  }

  Future<void> set({int? minutes, int? strengthDays}) async {
    state = WeeklyTargets(minutes: minutes ?? state.minutes, strengthDays: strengthDays ?? state.strengthDays);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_minutes, state.minutes);
    await prefs.setInt(_strength, state.strengthDays);
  }
}

final weeklyTargetsProvider = NotifierProvider<WeeklyTargetsNotifier, WeeklyTargets>(WeeklyTargetsNotifier.new);

/// The 7 days to [today] against the weekly targets.
final weeklyGuideProvider = FutureProvider.autoDispose.family<WeeklyGuide, DateTime>((ref, today) async {
  final db = ref.watch(databaseProvider);
  final targets = ref.watch(weeklyTargetsProvider);
  final end = dayOf(today);
  final weekStart = DateTime(end.year, end.month, end.day - 6);
  final recent = await db.getExerciseEntriesInRange(DateTime(end.year, end.month, end.day - 27), end);
  final watch = await HealthRepository(db).series('intensity_minutes', weekStart, end);
  return WeeklyGuide.from(
    week: [for (final e in recent) if (!dayOf(e.date).isBefore(weekStart)) e],
    recent: recent,
    watchMinutes: {for (final m in watch) dayOf(m.date): m.value},
    targets: targets,
  );
});
