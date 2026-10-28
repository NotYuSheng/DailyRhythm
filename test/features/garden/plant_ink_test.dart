import 'package:daily_rhythm/features/garden/data/plant_style_provider.dart';
import 'package:daily_rhythm/features/garden/domain/plant.dart';
import 'package:daily_rhythm/features/garden/domain/plant_ink.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every plant and pot draws in ink and wash', () {
    for (final species in PlantSpecies.values) {
      final svg = PlantSvg.plant(PlantSpec(species: species), style: PlantStyle.ink)!;
      expect(svg, startsWith('<svg'));
      expect('<'.allMatches(svg).length, '>'.allMatches(svg).length, reason: '$species');
      expect(svg, contains('stroke="${PlantInk.ink}"'), reason: 'inked lines');
      expect(svg, isNot(contains('<ellipse')), reason: 'shapes become paths so they can wobble');
    }
    expect(PlantSvg.pot('#F2A27E', style: PlantStyle.ink), contains('stroke="${PlantInk.ink}"'));
    expect(PlantSvg.plant(const PlantSpec(species: PlantSpecies.fern, logged: false), style: PlantStyle.ink), isNull);
  });

  test('washes are pale and outlined in register, the same wobble every time', () {
    final svg = PlantSvg.plant(const PlantSpec(species: PlantSpecies.tulip), style: PlantStyle.ink)!;
    expect(svg, isNot(contains('#5BB884')), reason: 'the green is washed out');
    expect(svg, isNot(contains('translate(3.5')), reason: 'no offset layer: wash and line together');
    expect(PlantSvg.plant(const PlantSpec(species: PlantSpecies.tulip), style: PlantStyle.ink), svg);
  });

  test('a cactus arm, a thick stroke, becomes an outlined tube', () {
    final svg = PlantSvg.plant(const PlantSpec(species: PlantSpecies.cactus), style: PlantStyle.ink)!;
    expect(svg, contains('stroke="${PlantInk.ink}" stroke-width="22.4"'));
    expect(svg, contains('stroke-width="18.0"'));
  });

  test('the style is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(plantStyleProvider), PlantStyle.soft);
    await container.read(plantStyleProvider.notifier).set(PlantStyle.ink);
    expect((await SharedPreferences.getInstance()).getString('plant_style'), 'ink');
  });
}
