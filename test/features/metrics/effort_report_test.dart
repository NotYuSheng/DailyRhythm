import 'package:daily_rhythm/features/garden/domain/garden_day.dart';
import 'package:daily_rhythm/features/garden/domain/plant.dart';
import 'package:daily_rhythm/features/metrics/data/models/metric_data.dart';
import 'package:daily_rhythm/features/metrics/data/services/effort_report.dart';
import 'package:flutter_test/flutter_test.dart';

GardenDay day(int d, int? effort) => GardenDay(
      date: DateTime(2026, 11, d), // 2 Nov 2026 is a Monday
      plant: const PlantSpec(species: PlantSpecies.sunflower, season: Season.autumn),
      chosen: false,
      effort: effort,
    );

void main() {
  test('counts exercise days by level, the usual level and the hardest weekday', () {
    final r = EffortReport.from([day(2, 2), day(3, null), day(4, 3), day(7, 5), day(9, 2), day(14, 4)]);
    expect(r.byLevel, [0, 2, 1, 1, 1]);
    expect((r.exerciseDays, r.hardDays, r.days), (5, 2, 6));
    expect(r.usual, 3, reason: 'the middle of Easy, Easy, Moderate, Hard, Very hard');
    expect(r.byWeekday[0], 2, reason: 'Mondays 2 and 9 Nov were both Easy');
    expect(r.hardestWeekday, DateTime.saturday);
    expect(r.perWeek, isNull, reason: 'nothing to compare with');
  });

  test('compares exercise days a week with the period before', () {
    final now = [for (var d = 1; d <= 14; d++) day(d, d.isEven ? 3 : null)]; // 7 in 14 days
    final before = [for (var d = 1; d <= 14; d++) day(d, d % 7 == 0 ? 2 : null)]; // 2 in 14 days
    final r = EffortReport.from(now, previous: before, previousLength: 14);
    expect(r.perWeek, closeTo(3.5, 0.01));
    expect(r.previousPerWeek, closeTo(1, 0.01));
  });

  test('the period before is the same kind of calendar period', () {
    final today = DateTime(2026, 11, 9);
    expect(previousPeriod(DateRange.month(today, today: today))!.label, 'October 2026');
    expect(previousPeriod(DateRange.year(today, today: today))!.label, '2025');
    expect(previousPeriod(DateRange.week(today, today: today))!.start, DateTime(2026, 11, 2));
    expect(previousPeriod(DateRange.allTime()), isNull);
  });
}
