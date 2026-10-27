import 'package:daily_rhythm/features/metrics/data/models/period_overview.dart';
import 'package:daily_rhythm/features/metrics/data/models/metric_data.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int month, int day) => DateTime(2025, month, day);

PeriodOverview build({
  OverviewScale scale = OverviewScale.year,
  DateTime? start,
  DateTime? end,
  Set<DateTime>? logged,
  Map<DateTime, int> moods = const {},
  Map<DateTime, double> sleep = const {},
  List<NightSpan> nights = const [],
  Map<String, Set<DateTime>> tags = const {},
  Map<DateTime, double> food = const {},
  Map<DateTime, double> events = const {},
  DateTime? today,
}) =>
    PeriodOverview.build(
      scale: scale,
      start: start ?? DateTime(2025),
      end: end ?? DateTime(2025, 12, 31),
      today: today ?? DateTime(2026, 1, 10),
      logged: logged ?? {for (var i = 1; i <= 20; i++) d(3, i)},
      sleepHours: sleep,
      steps: const {},
      kcal: const {},
      moods: moods,
      energy: const {},
      nights: nights,
      tagDays: tags,
      foodSpend: food,
      eventSpend: events,
    );

void main() {
  int cells(PeriodOverview o) => o.grid.fold(0, (n, r) => n + r.cells.whereType<DayValues>().length);

  test('a past year has every day; this year stops at today', () {
    expect(cells(build()), 365);
    expect(cells(build(today: DateTime(2025, 3, 10))), 69);
    final o = build();
    expect(o.grid.map((r) => r.label).join(), 'JFMAMJJASOND');
    expect(o.grid[1].cells.whereType<DayValues>().length, 28, reason: 'no March days in February’s row');
  });

  test('mood by month counts days per level', () {
    final o = build(moods: {d(3, 1): 3, d(3, 2): 3, d(3, 3): 2, d(4, 1): 5});
    expect(o.moodByGroup[2], [0, 1, 2, 0, 0]);
    expect(o.moodByGroup[3], [0, 0, 0, 0, 1]);
  });

  test('a week groups by day, a month by week, all time by year', () {
    final week = build(scale: OverviewScale.week, start: d(3, 3), end: d(3, 9), moods: {d(3, 4): 4});
    expect(week.groups.map((g) => g.label), ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
    expect(week.moodByGroup[1], [0, 0, 0, 1, 0]);
    expect((week.grid.single.cells.length, week.columnLabels.length), (7, 7));

    // March 2025 starts on a Saturday.
    final month = build(scale: OverviewScale.month, start: d(3, 1), end: d(3, 31));
    expect(month.groups.map((g) => g.label), ['1–2', '3–9', '10–16', '17–23', '24–30', '31']);
    expect(month.grid.length, 6, reason: 'calendar weeks');
    expect(month.grid.first.cells.whereType<DayValues>().length, 2, reason: 'Monday to Friday are February');
    expect(cells(month), 31);

    final all = build(scale: OverviewScale.all, start: DateTime(2024), end: DateTime(2025, 12, 31), sleep: {DateTime(2024, 1, 2): 6, DateTime(2024, 1, 4): 8});
    expect(all.groups.map((g) => g.label), ['2024', '2025']);
    expect(all.grid.map((r) => r.label), ["'24", "'25"]);
    expect(all.grid.first.cells.first!.sleepHours, 7, reason: 'a week’s cell averages its days');
    expect(all.rows.map((r) => r.group.label), ['2024', '2025']);
  });

  test('sleep by month: median bedtime and wake, and the middle half of each', () {
    final nights = [
      for (final (day, bed, wake) in [(1, 6.0, 13.0), (2, 6.5, 13.5), (3, 7.0, 14.0), (4, 5.0, 12.0)]) NightSpan(d(3, day), bed, wake),
    ];
    final m = build(nights: nights, sleep: {d(3, 1): 7, d(3, 2): 7}).sleepByGroup.single;
    expect((m.group.start.month, m.bed, m.wake, m.bedLow, m.bedHigh, m.hours), (3, 6.5, 13.5, 6.0, 7.0, 7.0));
    expect(NightSpan.fromClock(DateTime(2025, 1, 1, 0, 30)), 6.5);
    expect(NightSpan.fromClock(DateTime(2025, 1, 1, 19, 30)), 1.5, reason: 'an early night fits');
    expect(NightSpan.fromClock(DateTime(2025, 1, 1, 12, 30)), 18.5, reason: 'so does a late lie-in');
  });

  test('everyday tags are named, not listed; rare tags most used first', () {
    final everyDay = {for (var i = 1; i <= 20; i++) d(3, i)};
    final o = build(tags: {'Work': everyDay, 'Hike': {d(3, 2), d(3, 9)}, 'Party': {d(3, 5)}});
    expect(o.everydayTags, ['Work']);
    expect(o.rareTags.map((t) => (t.name, t.days.length)), [('Hike', 2), ('Party', 1)]);
  });

  test('a year with only watch data still has its months', () {
    final o = build(logged: const {}, sleep: {d(2, 1): 6.5});
    expect((o.loggedDays, o.hasData, o.rows.single.group.label), (0, true, 'Feb'));
  });

  test('a row only for months with logs, with spending and averages', () {
    final o = build(sleep: {d(3, 1): 6, d(3, 2): 8}, food: {d(3, 1): 4.5, d(3, 2): 5}, events: {d(3, 9): 60});
    final march = o.rows.single;
    expect((march.group.label, march.days, march.sleep, march.food, march.events), ('Mar', 20, 7.0, 9.5, 60.0));
  });

  test('average steps over the period, for the calorie range', () {
    final o = PeriodOverview.build(
      scale: OverviewScale.week,
      start: d(3, 3),
      end: d(3, 9),
      today: DateTime(2026),
      logged: const {},
      sleepHours: const {},
      steps: {d(3, 3): 6000, d(3, 4): 8000, d(3, 20): 20000},
      kcal: const {},
      moods: const {},
      energy: const {},
      nights: const [],
      tagDays: const {},
      foodSpend: const {},
      eventSpend: const {},
    );
    expect(o.averageSteps, 7000);
  });

  test('calendar periods for stepping', () {
    final today = DateTime(2026, 10, 27);
    final week = DateRange.week(DateTime(2026, 10, 22), today: today);
    expect((week.start, week.end, week.label), (DateTime(2026, 10, 19), DateTime(2026, 10, 25), '19–25 Oct'));
    final thisWeek = DateRange.week(today, today: today);
    expect(thisWeek.end, today, reason: 'cut at today while still going');
    expect(DateRange.week(DateTime(2026, 9, 30), today: today).label, '28 Sep – 4 Oct');
    expect(DateRange.month(DateTime(2026, 2, 10), today: today).end, DateTime(2026, 2, 28));
    expect(DateRange.month(DateTime(2026, 2, 10), today: today).label, 'February 2026');
    expect(DateRange.year(DateTime(2025, 5, 1), today: today).label, '2025');
  });
}
