import '../../../../shared/services/database/database_service.dart';
import '../../../../shared/services/database/repositories/catalog_repository.dart';
import '../../../../shared/services/database/repositories/checkin_repository.dart';
import '../../../../shared/services/database/repositories/spending_repository.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../garden/data/garden_repository.dart';
import '../../../garden/domain/garden_day.dart';
import '../../../tags/data/models/tag.dart';
import '../models/period_overview.dart';

/// Reads a period from every table for [PeriodOverview].
class PeriodOverviewRepository {
  PeriodOverviewRepository([DatabaseService? db]) : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  /// [scale]'s overview from [from] to [to]. All time starts on 1 January
  /// of the first logged year, not the range's placeholder start.
  Future<PeriodOverview> load(OverviewScale scale, DateTime from, DateTime to, {DateTime? today}) async {
    final now = dayOf(today ?? DateTime.now());
    var start = dayOf(from);
    if (scale == OverviewScale.all) {
      start = DateTime((await _db.firstLoggedDay())?.year ?? now.year);
    }
    final end = dayOf(to).isAfter(now) ? now : dayOf(to);
    if (start.isAfter(now)) {
      return _build(scale, start, end, now, logged: const {});
    }

    // The garden's own day logs: plants, sleep (the app's log first, the
    // watch for the rest), steps, mood and tags, read once.
    final logs = await GardenRepository(_db).logsInRange(start, end);
    final logged = {for (final l in logs) if (GardenDay.from(l).plant.logged) l.date};
    final sleepHours = {for (final l in logs) if (l.sleepHours != null) l.date: l.sleepHours!};
    final steps = {for (final l in logs) if (l.steps != null) l.date: l.steps!};
    final moods = {for (final l in logs) if (l.dayMood != null) l.date: l.dayMood!};

    // Each night's bedtime is the evening before its day.
    final entries = await _db.getSleepEntriesInRange(DateTime(start.year, start.month, start.day - 1), end);
    final byDay = {for (final e in entries) dayOf(e.date): e};
    final nights = <NightSpan>[];
    for (final MapEntry(key: day, value: e) in byDay.entries) {
      if (day.isBefore(start)) continue;
      final bedtime = byDay[DateTime(day.year, day.month, day.day - 1)]?.sleepTime;
      if (bedtime != null && e.wakeUpTime != null) {
        final bed = NightSpan.fromClock(bedtime);
        final wake = NightSpan.fromClock(e.wakeUpTime!);
        if (wake > bed) nights.add(NightSpan(day, bed, wake));
      }
    }

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

    final energy = <DateTime, int>{
      for (final c in await CheckinRepository(_db).inRange(start, end))
        if (c.energy != null) dayOf(c.date): c.energy!,
    };

    // Activities and symptoms; food sources say where meals came from.
    final foodSources = {for (final t in await _db.getAllTags()) if (t.knownKind == TagKind.foodSource) t.name};
    final tagDays = <String, Set<DateTime>>{};
    for (final l in logs) {
      for (final name in l.tagNames) {
        if (!foodSources.contains(name)) (tagDays[name] ??= {}).add(l.date);
      }
    }

    return _build(
      scale,
      start,
      end,
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

  PeriodOverview _build(
    OverviewScale scale,
    DateTime start,
    DateTime end,
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
      PeriodOverview.build(
        scale: scale,
        start: start,
        end: end,
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
