import 'package:daily_rhythm/features/meals/domain/diet_score.dart';
import 'package:daily_rhythm/features/meals/domain/modifiers.dart';
import 'package:daily_rhythm/features/meals/domain/plate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('built-in modifiers move calories and health; typed ones only label', () {
    expect(Modifier.kcalChange(['less_rice', 'extra_cheese', 'Extra chilli']), -20);
    expect(Modifier.tags(['less_sugar', 'extra_cheese', 'Extra chilli']), {'made_lighter', 'made_richer'});
    expect(Modifier.labelOf('no_butter'), 'No butter');
    expect(Modifier.labelOf('Extra chilli'), 'Extra chilli');
  });

  test('a name that says it, like kopi siew dai, counts as made lighter', () {
    expect(DietScore.detect('Kopi siew dai'), contains('made_lighter'));
    expect(DietScore.forFood('Kopi siew dai')!.score, 3.5);
  });

  test('modifiers are stored with the plate changes', () {
    final stored = Plate.encodeChanges(const [PlateChange('Fries', swapFor: 'Corn')], ['no_butter']);
    expect(Plate.decodeChanges(stored), const [PlateChange('Fries', swapFor: 'Corn')]);
    expect(Plate.decodeMods(stored), ['no_butter']);
    expect(Plate.encodeChanges(const [], ['less_sugar']), isNotNull);
  });
}
