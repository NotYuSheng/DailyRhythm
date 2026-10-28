import 'package:daily_rhythm/features/garden/data/plant_style_provider.dart';
import 'package:daily_rhythm/features/garden/domain/plant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every plant and pot draws in ink and wash', () {
    for (final species in PlantSpecies.values) {
      final svg = PlantSvg.plant(PlantSpec(species: species), style: PlantStyle.ink)!;
      expect(svg, startsWith('<svg'));
      expect('<'.allMatches(svg).length, '>'.allMatches(svg).length, reason: '$species');
      expect(svg, contains('stroke="#2F3A35"'), reason: 'inked lines');
    }
    expect(PlantSvg.pot('#F2A27E', style: PlantStyle.ink), contains('stroke="#2F3A35"'));
    expect(PlantSvg.plant(const PlantSpec(species: PlantSpecies.fern, logged: false), style: PlantStyle.ink), isNull);
  });

  test('the lines are outlines over a paler, offset wash', () {
    final svg = PlantSvg.plant(const PlantSpec(species: PlantSpecies.tulip), style: PlantStyle.ink)!;
    final wash = RegExp(r'<g transform="translate\(3.5 2.5\)" opacity="0.85">(.*)</g><g>', dotAll: true).firstMatch(svg)!.group(1)!;
    final lines = svg.substring(svg.lastIndexOf('<g>'));
    expect(wash, isNot(contains('#5BB884')), reason: 'the green is paled');
    expect(RegExp(r'fill="#').hasMatch(lines), isFalse, reason: 'lines carry no colour fills');
  });

  test('a fern\'s leaflets stay wash only', () {
    final svg = PlantSvg.plant(const PlantSpec(species: PlantSpecies.fern), style: PlantStyle.ink)!;
    final lines = svg.substring(svg.lastIndexOf('<g>'));
    expect(lines, isNot(contains('<ellipse')));
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
