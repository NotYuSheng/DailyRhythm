import 'package:daily_rhythm/features/garden/domain/garden_day.dart';
import 'package:daily_rhythm/features/garden/domain/plant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => Season.southern = false);

  test('a kind of day keeps its family and grows its season\'s member', () {
    expect([for (final s in Season.values) PlantSpecies.cactus.nameIn(s)], ['barrel cactus', 'cactus', 'prickly pear', 'Christmas cactus']);
    expect([for (final s in Season.values) PlantSpecies.tree.nameIn(s)], ['cherry blossom', 'little tree', 'maple', 'snowy pine']);
    expect(PlantSpecies.cactus.pluralIn(Season.winter), 'Christmas cacti');
  });

  test('a day\'s plant takes its season and a variety that changes day to day', () {
    final a = PlantSpec.on(DateTime(2026, 10, 1), species: PlantSpecies.sunflower);
    final b = PlantSpec.on(DateTime(2026, 10, 2), species: PlantSpecies.sunflower);
    expect((a.season, a.name), (Season.autumn, 'chrysanthemum'));
    expect(a.variety, isNot(b.variety));
    expect({for (var d = 1; d <= 3; d++) PlantSpec.on(DateTime(2026, 10, d), species: PlantSpecies.sunflower).variety}, {0, 1, 2});
  });

  test('in the south October is spring', () {
    Season.southern = true;
    expect(PlantSpec.on(DateTime(2026, 10, 1), species: PlantSpecies.tree).name, 'cherry blossom');
  });

  test('every kind draws in every season and variety, each one different', () {
    final drawn = <String>{};
    for (final s in PlantSpecies.values) {
      for (final season in Season.values) {
        for (var v = 0; v < varietyCount; v++) {
          final svg = PlantSvg.plant(PlantSpec(species: s, season: season, variety: v))!;
          expect(svg, startsWith('<svg'));
          drawn.add(svg);
        }
      }
    }
    expect(drawn.length, PlantSpecies.values.length * Season.values.length * varietyCount);
    expect(PlantSvg.plant(PlantSpec(species: PlantSpecies.fern, logged: false, season: Season.winter)), isNull);
  });

  test('the day\'s title names its seasonal plant', () {
    final day = GardenDay.from(DayLog(date: DateTime(2026, 1, 10), tagNames: const ['Work']));
    expect(day.title, 'A Christmas cactus: a work day');
  });
}
