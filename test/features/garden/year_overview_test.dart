import 'package:daily_rhythm/features/garden/domain/year_overview.dart';
import 'package:daily_rhythm/features/metrics/data/models/metric_data.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int month, int day) => DateTime(2025, month, day);

YearOverview build({
  Set<DateTime>? logged,
  Map<DateTime, int> moods = const {},
  Map<DateTime, double> sleep = const {},
  List<NightSpan> nights = const [],
  Map<String, Set<DateTime>> tags = const {},
  Map<DateTime, double> food = const {},
  Map<DateTime, double> events = const {},
  DateTime? today,
}) =>
    YearOverview.build(
      year: 2025,
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
  test('a past year has every day; this year stops at today', () {
    expect(build().days.length, 365);
    expect(build(today: DateTime(2025, 3, 10)).days.length, 69);
  });

  test('mood by month counts days per level', () {
    final o = build(moods: {d(3, 1): 3, d(3, 2): 3, d(3, 3): 2, d(4, 1): 5});
    expect(o.moodByMonth[2], [0, 1, 2, 0, 0]);
    expect(o.moodByMonth[3], [0, 0, 0, 0, 1]);
  });

  test('sleep by month: median bedtime and wake, and the middle half of each', () {
    final nights = [
      for (final (day, bed, wake) in [(1, 6.0, 13.0), (2, 6.5, 13.5), (3, 7.0, 14.0), (4, 5.0, 12.0)]) NightSpan(d(3, day), bed, wake),
    ];
    final m = build(nights: nights, sleep: {d(3, 1): 7, d(3, 2): 7}).sleepByMonth.single;
    expect((m.month, m.bed, m.wake, m.bedLow, m.bedHigh, m.hours), (3, 6.5, 13.5, 6.0, 7.0, 7.0));
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
    expect((o.loggedDays, o.hasData, o.months.single.month), (0, true, 2));
  });

  test('a row only for months with logs, with spending and averages', () {
    final o = build(sleep: {d(3, 1): 6, d(3, 2): 8}, food: {d(3, 1): 4.5, d(3, 2): 5}, events: {d(3, 9): 60});
    final march = o.months.single;
    expect((march.month, march.days, march.sleep, march.food, march.events), (3, 20, 7.0, 9.5, 60.0));
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
