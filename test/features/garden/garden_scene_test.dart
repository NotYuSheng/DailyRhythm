import 'package:daily_rhythm/features/garden/domain/garden_scene.dart';
import 'package:daily_rhythm/features/garden/domain/plant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the season follows the month, northern calendar by default', () {
    expect([for (final m in [1, 4, 7, 10, 12]) SceneLook.forMonth(m)],
        [SceneLook.winter, SceneLook.spring, SceneLook.summer, SceneLook.autumn, SceneLook.winter]);
  });

  test('in the southern hemisphere the seasons flip; the tropics keep the northern calendar', () {
    expect(SceneLook.southern('AU'), isTrue);
    expect(SceneLook.southern('nz'), isTrue);
    expect(SceneLook.southern('SG'), isFalse, reason: 'no seasons, so still show them');
    expect(SceneLook.southern(null), isFalse);
    expect(SceneLook.forMonth(10, southern: true), SceneLook.spring);
    expect(SceneLook.forMonth(1, southern: true), SceneLook.summer);
  });

  test('a week or month gets its season, a year golden hour, dark mode night', () {
    expect(SceneLook.forPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31)), SceneLook.autumn);
    expect(SceneLook.forPeriod(DateTime(2026, 2, 23), DateTime(2026, 3, 1)), SceneLook.winter);
    expect(SceneLook.forPeriod(DateTime(2026, 1, 1), DateTime(2026, 12, 31)), SceneLook.wholeYear);
    expect(SceneLook.forPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31), dark: true), SceneLook.night);
  });

  test('a long period is sampled down in the same mix', () {
    final plants = [
      for (var i = 0; i < 200; i++) PlantSpecies.sprout,
      for (var i = 0; i < 100; i++) PlantSpecies.cactus,
      for (var i = 0; i < 30; i++) PlantSpecies.tree,
    ];
    final shown = GardenScene.sample(plants);
    expect(shown.length, GardenScene.maxPlants);
    int count(PlantSpecies s) => shown.where((p) => p == s).length;
    expect((count(PlantSpecies.sprout), count(PlantSpecies.cactus), count(PlantSpecies.tree)), (28, 14, 4));
    expect(GardenScene.sample(plants.take(10).toList()).length, 10, reason: 'short periods show every plant');
  });

  test('the same plants and seed draw the same scene, one plant group each', () {
    final plants = [PlantSpecies.tulip, PlantSpecies.fern, PlantSpecies.sunflower, PlantSpecies.tree];
    final a = GardenScene.svg(plants, SceneLook.autumn, seed: 5);
    expect(a, GardenScene.svg(plants, SceneLook.autumn, seed: 5));
    expect(RegExp('opacity="0.16"').allMatches(a).length, plants.length, reason: 'one shadow per plant');
    expect(GardenScene.svg(const [], SceneLook.winter), contains('</svg>'), reason: 'an empty period still has its hills');
  });
}
