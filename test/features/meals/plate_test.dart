import 'package:daily_rhythm/features/meals/domain/diet_score.dart';
import 'package:daily_rhythm/features/meals/domain/plate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final kcal = {'fries': 330.0, 'corn': 90.0, 'coleslaw': 150.0};
  double? kcalOf(String n) => kcal[n.toLowerCase()];

  test('a swap or a left-out side changes the calories; unknown ones don\'t', () {
    expect(Plate.kcalChange(const [PlateChange('Fries', swapFor: 'Corn')], kcalOf), -240);
    expect(Plate.kcalChange(const [PlateChange('Coleslaw')], kcalOf), -150);
    expect(Plate.kcalChange(const [PlateChange('Fries', swapFor: 'Mystery')], kcalOf), 0);
  });

  test('corn instead of fries takes away fried, unless the main is fried too', () {
    final sides = ['Fries', 'Coleslaw'];
    Set<String> tagsOf(String n) => DietScore.detect(n);
    final usual = Plate.usualTags('Chicken chop', sides, tagsOf);
    expect(usual, {'fried'});
    expect(
      Plate.changedTags(name: 'Chicken chop', usual: usual, sides: sides, changes: const [PlateChange('Fries', swapFor: 'Corn')], tagsOf: tagsOf),
      isEmpty,
    );
    final fried = Plate.usualTags('Fried chicken', sides, tagsOf);
    expect(
      Plate.changedTags(name: 'Fried chicken', usual: fried, sides: sides, changes: const [PlateChange('Fries', swapFor: 'Corn')], tagsOf: tagsOf),
      ['fried'],
    );
    expect(
      Plate.changedTags(name: 'Chicken chop', usual: usual, sides: sides, changes: const [PlateChange('Coleslaw', swapFor: 'Salad')], tagsOf: tagsOf),
      ['fried', 'vegetables'],
    );
  });

  test('sides and changes round-trip as stored', () {
    expect(Plate.parseSides('Fries, coleslaw;; fries'), ['Fries', 'coleslaw']);
    const changes = [PlateChange('Fries', swapFor: 'Corn'), PlateChange('Coleslaw')];
    expect(Plate.decodeChanges(Plate.encodeChanges(changes)), changes);
    expect(Plate.decodeSides(Plate.encodeSides(['Fries'])), ['Fries']);
    expect(Plate.encodeChanges(const []), isNull);
    expect(Plate.decodeChanges(null), isEmpty);
  });
}
