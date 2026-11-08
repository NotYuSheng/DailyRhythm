import 'package:daily_rhythm/features/garden/domain/garden_day.dart';
import 'package:daily_rhythm/features/garden/domain/plant.dart';
import 'package:daily_rhythm/features/garden/domain/year_facts.dart';
import 'package:flutter_test/flutter_test.dart';

GardenDay day(int month, int d, PlantSpecies? species) => GardenDay(
      date: DateTime(2025, month, d),
      chosen: false,
      plant: PlantSpec(species: species ?? PlantSpecies.sprout, logged: species != null),
    );

void main() {
  test('the fullest month, the plant grown most and the quiet days', () {
    final f = YearFacts.from([
      day(1, 1, PlantSpecies.cactus),
      day(3, 1, PlantSpecies.fern),
      day(3, 2, PlantSpecies.fern),
      day(3, 3, PlantSpecies.cactus),
      day(3, 4, null),
    ]);
    expect((f.plants, f.quietDays, f.fullestMonth, f.fullestCount), (4, 1, DateTime(2025, 3), 3));
    expect((f.commonest, f.commonestCount), (PlantSpecies.cactus, 2), reason: 'the first to reach the most on a tie');
  });

  test('a year with nothing grown has no fullest month', () {
    final f = YearFacts.from([day(1, 1, null)]);
    expect((f.plants, f.fullestMonth, f.commonest), (0, null, null));
  });
}
