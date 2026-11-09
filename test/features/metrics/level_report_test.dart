import 'package:daily_rhythm/features/metrics/data/models/metric_data.dart';
import 'package:daily_rhythm/features/metrics/data/services/level_report.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime nov(int d) => DateTime(2026, 11, d); // 2 Nov 2026 is a Monday

void main() {
  test('counts days by level and by weekday, the usual level and the busiest weekday', () {
    final r = LevelReport.from({nov(2): 1, nov(4): 2, nov(7): 4, nov(9): 1, nov(14): 3, nov(21): 3}, days: 30);
    expect(r.byLevel, [0, 2, 1, 2, 1]);
    expect(r.counted, 6);
    expect(r.usual, 2);
    expect(r.byWeekday[5], [0, 0, 0, 2, 1], reason: 'three Saturdays');
    expect(r.busiestWeekday, DateTime.saturday);
    expect(r.perWeek, isNull, reason: 'nothing to compare with');
  });

  test('compares days a week and the average with the period before', () {
    final r = LevelReport.from(
      {nov(1): 2, nov(2): 2},
      days: 14,
      values: {nov(1): 2000, nov(2): 2200},
      previous: {nov(1): 1},
      previousDays: 7,
      previousValues: {nov(1): 1800},
    );
    expect((r.perWeek, r.previousPerWeek), (1, 1));
    expect((r.average, r.previousAverage), (2100, 1800));
  });

  test('calorie bands follow your range when there is one', () {
    expect(calorieBand(1500), 0);
    expect(calorieBand(2000), 2);
    expect(calorieBand(2000, low: 1900, high: 2300), 2, reason: 'in range');
    expect(calorieBand(2500, low: 1900, high: 2300), 3);
    expect(calorieBand(2800, low: 1900, high: 2300), 4);
  });

  test('the period before is the same kind of calendar period', () {
    final today = DateTime(2026, 11, 9);
    expect(previousPeriod(DateRange.month(today, today: today))!.label, 'October 2026');
    expect(previousPeriod(DateRange.year(today, today: today))!.label, '2025');
    expect(previousPeriod(DateRange.week(today, today: today))!.start, DateTime(2026, 11, 2));
    expect(previousPeriod(DateRange.allTime()), isNull);
    expect(previousWord(DateRange.week(today, today: today)), 'last week');
  });
}
