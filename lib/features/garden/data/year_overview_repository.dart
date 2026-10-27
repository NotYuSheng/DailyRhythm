import '../../../shared/services/database/database_service.dart';
import '../../../shared/services/database/repositories/catalog_repository.dart';
import '../../../shared/services/database/repositories/checkin_repository.dart';
import '../../../shared/services/database/repositories/health_repository.dart';
import '../../../shared/services/database/repositories/spending_repository.dart';
import '../../../shared/utils/date_utils.dart';
import '../../tags/data/models/tag.dart';
import '../domain/year_overview.dart';
import 'garden_repository.dart';

/// Reads one year from every table for [YearOverview].
class YearOverviewRepository {
  YearOverviewRepository([DatabaseService? db]) : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  /// The years with anything logged, oldest first, up to [today]'s.
  Future<List<int>> years({DateTime? today}) async {
    final now = today ?? DateTime.now();
    final first = await _db.firstLoggedDay();
    return [for (var y = first?.year ?? now.year; y <= now.year; y++) y];
  }

  Future<YearOverview> load(int year, {DateTime? today}) async {
    final now = dayOf(today ?? DateTime.now());
    final start = DateTime(year);
    final end = year == now.year ? now : DateTime(year, 12, 31);
    if (start.isAfter(now)) {
      return _build(year, now, logged: const {});
    }

    final garden = await GardenRepository(_db).daysInRange(start, end);
    final logged = {for (final g in garden) if (g.plant.logged) g.date};

    // Sleep: the app's log first, the watch for nights without one. Each
    // night's bedtime is the evening before its day.
    final entries = await _db.getSleepEntriesInRange(DateTime(year - 1, 12, 31), end);
    final byDay = {for (final e in entries) dayOf(e.date): e};
    final sleepHours = <DateTime, double>{
      for (final m in await HealthRepository(_db).series('sleep_minutes', start, end)) dayOf(m.date): m.value / 60,
    };
    final nights = <NightSpan>[];
    for (final MapEntry(key: day, value: e) in byDay.entries) {
      if (day.year != year) continue;
      if (e.totalHours != null) sleepHours[day] = e.totalHours!;
      final bedtime = byDay[DateTime(day.year, day.month, day.day - 1)]?.sleepTime;
      if (bedtime != null && e.wakeUpTime != null) {
        final bed = NightSpan.fromClock(bedtime);
        final wake = NightSpan.fromClock(e.wakeUpTime!);
        if (wake > bed) nights.add(NightSpan(day, bed, wake));
      }
    }

    final steps = {for (final m in await HealthRepository(_db).series('steps', start, end)) dayOf(m.date): m.value};

    final foodKcal = await CatalogRepository(_db).foodCalories();
    final kcal = <DateTime, double>{};
    final foodSpend = <DateTime, double>{};
    for (final m in await _db.getMealEntriesInRange(start, end)) {
      final day = dayOf(m.date);
      if (m.caloriesWith(foodKcal) case final c?) kcal[day] = (kcal[day] ?? 0) + c;
      if (m.price != null && m.currency == 'SGD') foodSpend[day] = (foodSpend[day] ?? 0) + m.price!;
    }
    final eventSpend = <DateTime, double>{};
    for (final e in await SpendingRepository(_db).inRange(start, end)) {
      if (e.currency == 'SGD') eventSpend[dayOf(e.date)] = (eventSpend[dayOf(e.date)] ?? 0) + e.amount;
    }

    final moods = {for (final m in await _db.getMoodEntriesInRange(start, end)) dayOf(m.date): m.moodLevel};
    final energy = <DateTime, int>{
      for (final c in await CheckinRepository(_db).inRange(start, end))
        if (c.energy != null) dayOf(c.date): c.energy!,
    };

    // Activities and symptoms; food sources say where meals came from.
    final tags = {for (final t in await _db.getAllTags()) t.id: t};
    final tagDays = <String, Set<DateTime>>{};
    for (final a in await _db.getActivityEntriesInRange(start, end)) {
      final tag = tags[a.tagId];
      if (tag == null || tag.knownKind == TagKind.foodSource) continue;
      (tagDays[tag.name] ??= {}).add(dayOf(a.date));
    }

    return _build(
      year,
      now,
      logged: logged,
      sleepHours: sleepHours,
      steps: steps,
      kcal: kcal,
      moods: moods,
      energy: energy,
      nights: nights,
      tagDays: tagDays,
      foodSpend: foodSpend,
      eventSpend: eventSpend,
    );
  }

  YearOverview _build(
    int year,
    DateTime today, {
    required Set<DateTime> logged,
    Map<DateTime, double> sleepHours = const {},
    Map<DateTime, double> steps = const {},
    Map<DateTime, double> kcal = const {},
    Map<DateTime, int> moods = const {},
    Map<DateTime, int> energy = const {},
    List<NightSpan> nights = const [],
    Map<String, Set<DateTime>> tagDays = const {},
    Map<DateTime, double> foodSpend = const {},
    Map<DateTime, double> eventSpend = const {},
  }) =>
      YearOverview.build(
        year: year,
        today: today,
        logged: logged,
        sleepHours: sleepHours,
        steps: steps,
        kcal: kcal,
        moods: moods,
        energy: energy,
        nights: nights,
        tagDays: tagDays,
        foodSpend: foodSpend,
        eventSpend: eventSpend,
      );
}
