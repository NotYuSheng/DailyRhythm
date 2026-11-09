import 'package:daily_rhythm/features/garden/domain/garden_scene.dart';
import 'package:daily_rhythm/features/garden/domain/plant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the season follows the month, northern calendar by default', () {
    expect([for (final m in [1, 4, 7, 10, 12]) Season.ofMonth(m, southern: false)],
        [Season.winter, Season.spring, Season.summer, Season.autumn, Season.winter]);
    expect(SceneLook.of(Season.autumn), SceneLook.autumn);
  });

  test('in the southern hemisphere the seasons flip; the tropics keep the northern calendar', () {
    expect(Season.isSouthern('AU'), isTrue);
    expect(Season.isSouthern('nz'), isTrue);
    expect(Season.isSouthern('SG'), isFalse, reason: 'no seasons, so still show them');
    expect(Season.isSouthern(null), isFalse);
    expect(Season.ofMonth(10, southern: true), Season.spring);
    expect(Season.ofMonth(1, southern: true), Season.summer);
  });

  test('a week or month gets its season, a year golden hour, dark mode night', () {
    expect(SceneLook.forPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31)), SceneLook.autumn);
    expect(SceneLook.forPeriod(DateTime(2026, 2, 23), DateTime(2026, 3, 1)), SceneLook.winter);
    expect(SceneLook.forPeriod(DateTime(2026, 1, 1), DateTime(2026, 12, 31)), SceneLook.wholeYear);
    expect(SceneLook.forPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31), dark: true), SceneLook.night);
  });

  test('a long period is sampled down in the same mix', () {
    PlantSpec p(PlantSpecies s, int i) => PlantSpec(species: s, season: Season.values[i % 4]);
    final plants = [
      for (var i = 0; i < 200; i++) p(PlantSpecies.sprout, i),
      for (var i = 0; i < 100; i++) p(PlantSpecies.cactus, i),
      for (var i = 0; i < 30; i++) p(PlantSpecies.tree, i),
    ];
    final shown = GardenScene.sample(plants);
    expect(shown.length, GardenScene.maxPlants);
    int count(PlantSpecies s) => shown.where((p) => p.species == s).length;
    expect((count(PlantSpecies.sprout), count(PlantSpecies.cactus), count(PlantSpecies.tree)), (28, 14, 4));
    expect({for (final x in shown) if (x.species == PlantSpecies.sprout) x.season}, Season.values.toSet(), reason: 'every season shows');
    expect(GardenScene.sample(plants.take(10).toList()).length, 10, reason: 'short periods show every plant');
  });

  test('the same plants and seed draw the same scene, one plant group each', () {
    final plants = [for (final s in [PlantSpecies.tulip, PlantSpecies.fern, PlantSpecies.sunflower, PlantSpecies.tree]) PlantSpec(species: s, season: Season.autumn)];
    final a = GardenScene.svg(plants, SceneLook.autumn, seed: 5);
    expect(a, GardenScene.svg(plants, SceneLook.autumn, seed: 5));
    expect(RegExp('opacity="0.16"').allMatches(a).length, plants.length, reason: 'one shadow per plant');
    expect(GardenScene.svg(const [], SceneLook.winter), contains('</svg>'), reason: 'an empty period still has its hills');
  });

  test('in layers, plants sway on their ridges and the weather can be left to animate', () {
    final plants = [for (var i = 0; i < 12; i++) PlantSpec(species: PlantSpecies.values[i % 8], season: Season.winter)];
    final layers = GardenScene.layers(plants, SceneLook.winter, seed: 3);
    expect(GardenScene.wrap(layers.map((l) => l.body).join()), GardenScene.svg(plants, SceneLook.winter, seed: 3), reason: 'the same picture');
    expect(layers.where((l) => l.swayBaseY != null).length, 4, reason: 'each ridge’s plants sway together');
    final still = GardenScene.layers(plants, SceneLook.winter, seed: 3, weather: false).map((l) => l.body).join();
    expect(RegExp('r="[0-9.]+" fill="#FFFFFF" opacity="0.9"').hasMatch(still), isFalse, reason: 'snow is drawn by the animation');
  });
}
