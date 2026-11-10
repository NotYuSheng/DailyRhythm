import 'package:daily_rhythm/features/garden/domain/garden_day.dart';
import 'package:daily_rhythm/features/garden/domain/plant.dart';
import 'package:daily_rhythm/features/metrics/data/models/metric_data.dart';
import 'package:daily_rhythm/features/metrics/presentation/widgets/garden_scene_card.dart';
import 'package:flutter_test/flutter_test.dart';

GardenDay day(int month, int d, PlantSpecies? s) => GardenDay(
      date: DateTime(2026, month, d),
      plant: PlantSpec(species: s ?? PlantSpecies.sprout, logged: s != null, season: Season.autumn),
      chosen: false,
    );

void main() {
  final nov = DateRange.month(DateTime(2026, 11, 10), today: DateTime(2026, 11, 10));
  final work = PlantSpecies.cactus, people = PlantSpecies.tulip, mix = PlantSpecies.sprout;

  test('says how much was logged, then a clear change from last period', () {
    final now = [for (var d = 1; d <= 10; d++) day(11, d, d <= 6 ? people : (d == 10 ? null : work))];
    final before = [for (var d = 1; d <= 31; d++) day(10, d, d == 1 ? people : (d <= 21 ? work : mix))];
    expect(GardenSceneCard.caption(now, before, nov), '9 of 10 days logged. More days with people than last month: 67% of days, up from 3%.');
  });

  test('without a change, the longest run of one kind of day', () {
    final now = [for (var d = 1; d <= 10; d++) day(11, d, d >= 3 && d <= 7 ? work : mix)];
    expect(GardenSceneCard.caption(now, null, nov), '10 of 10 days logged. 5 work days in a row, 3–7 Nov.');
  });

  test('otherwise the kinds there were most of; all time counts from the first day', () {
    final now = [day(11, 1, work), day(11, 2, mix), day(11, 4, work), day(11, 6, mix)];
    expect(GardenSceneCard.caption(now, null, nov), '4 of 4 days logged. Mostly work days and mixed days.');
    final all = DateRange.allTime();
    expect(GardenSceneCard.caption(now, null, all), startsWith('4 days logged since Nov 2026.'));
    expect(GardenSceneCard.caption([day(11, 1, null)], null, nov), 'Nothing grew in this period yet.');
  });
}
