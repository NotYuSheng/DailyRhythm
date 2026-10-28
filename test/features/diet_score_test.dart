import 'package:daily_rhythm/features/meals/domain/diet_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double? score(String name) => DietScore.forFood(name)?.score;

  test('a typical plate is 3; what it is moves it, and says why', () {
    expect(score('Chicken rice'), 3);
    expect(DietScore.forFood('Fried rice')!.reasons, ['fried']);
    expect(score('Mcspicy'), 2);
    expect(score('Cheese rings'), 1.5);
    expect(score('Yong tau foo'), 4);
    expect(score('Fish soup rice'), 4.5);
    expect(score('Banana'), 4);
  });

  test('local names: carrot cake is fried, fish cake and fish and chips aren’t what they seem', () {
    expect(DietScore.forFood('Carrot cake')!.reasons, ['fried']);
    expect(DietScore.forFood('Fish cake noodles')!.reasons, ['fish or lean protein']);
    expect(DietScore.forFood('Fish and chips')!.reasons, ['fried']);
  });

  test('supplements and water aren’t scored', () {
    expect([score('Creatine'), score('Protein'), score('Water')], [null, null, null]);
  });

  test('a day weighs each meal by its calories', () {
    expect(DietScore.forDay([('Fried rice', 600), ('Banana', 100)]), closeTo((2 * 600 + 4 * 100) / 700, 0.001));
    expect(DietScore.forDay([('Creatine', null)]), isNull);
    expect(DietScore.levelFor(2.4), 2);
  });

  test('each food says its score and why', () {
    expect(DietScore.describe('Mcspicy'), 'Health 2/5 · fast food');
    expect(DietScore.describe('Fish soup rice'), 'Health 4.5/5 · steamed or soup, fish or lean protein');
    expect(DietScore.describe('Chicken rice'), 'Health 3/5 · a typical plate');
    expect(DietScore.describe('Creatine'), isNull);
  });
}
