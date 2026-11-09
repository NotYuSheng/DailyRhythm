import 'package:daily_rhythm/features/garden/domain/garden_day.dart';
import 'package:daily_rhythm/features/garden/domain/plant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => Season.southern = false);

  test('a kind of day keeps its family and grows its season\'s member', () {
    expect([for (final s in Season.values) PlantSpecies.cactus.nameIn(s)], ['barrel cactus', 'cactus', 'prickly pear', 'Christmas cactus']);
    expect([for (final s in Season.values) PlantSpecies.tree.nameIn(s)], ['cherry blossom', 'little tree', 'maple', 'snowy pine']);
    expect(PlantSpecies.cactus.pluralIn(Season.winter), 'Christmas cacti');
    expect([for (final s in Season.values) PlantSpecies.tree.nameIn(s, member: 1)], ['magnolia', 'palm', 'ginkgo', 'birch']);
    expect(PlantSpecies.succulent.pluralIn(Season.spring, member: 1), 'hens and chicks');
  });

  test('a day\'s plant takes its season and a variety that changes day to day', () {
    final a = PlantSpec.on(DateTime(2026, 10, 1), species: PlantSpecies.sunflower);
    final b = PlantSpec.on(DateTime(2026, 10, 2), species: PlantSpecies.sunflower);
    expect(a.season, Season.autumn);
    expect(a.name, isIn(['chrysanthemum', 'marigold']));
    expect(a.variety, isNot(b.variety));
    final week = [for (var d = 1; d <= 6; d++) PlantSpec.on(DateTime(2026, 10, d), species: PlantSpecies.sunflower)];
    expect({for (final p in week) p.variety}.length, 6, reason: 'six days, six different looks');
    expect({for (final p in week) p.name}, {'chrysanthemum', 'marigold'}, reason: 'both of the season\'s plants');
  });

  test('in the south October is spring', () {
    Season.southern = true;
    expect(PlantSpec.on(DateTime(2026, 10, 1), species: PlantSpecies.tree).name, isIn(['cherry blossom', 'magnolia']));
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

  test('the pot follows the season: snow on the rim in winter, a leaf in autumn', () {
    String pot(Season s) => PlantSvg.seasonalPot(PlantSpec(species: PlantSpecies.tulip, season: s));
    expect(pot(Season.spring), contains('#F7C8D6'));
    expect(pot(Season.summer), contains('#F2A27E'));
    expect(pot(Season.autumn), contains('#D7713F'));
    expect(pot(Season.winter), allOf(contains('#5B7BA6'), contains('#FFFFFF')));
    expect(PlantSvg.seasonalPot(PlantSpec(species: PlantSpecies.tulip, season: Season.summer, variety: 1)), contains('#8CC8FF'),
        reason: 'the shade follows the day\'s colour');
  });

  test('the day\'s title names its seasonal plant', () {
    final day = GardenDay.from(DayLog(date: DateTime(2026, 1, 10), tagNames: const ['Work']));
    expect(day.title, isIn(['A Christmas cactus: a work day', 'A snowball cactus: a work day']));
  });
}
