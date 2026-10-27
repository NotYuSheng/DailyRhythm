import 'package:daily_rhythm/features/meals/data/models/food_item.dart';
import 'package:daily_rhythm/features/meals/domain/calorie_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final estimator = CalorieEstimator(
    yourFoods: [
      FoodItem(name: 'Chicken rice', kcal: 620, aliases: ['chix rice']),
      FoodItem(name: 'Mystery stew'), // no calories: never used
    ],
    reference: const [
      ReferenceFood(name: 'Laksa', kcal: 590, aliases: ['curry laksa']),
      ReferenceFood(name: 'Chicken rice', kcal: 600),
      ReferenceFood(name: 'Kopi', kcal: 120),
      ReferenceFood(name: 'Fried rice', kcal: 650),
    ],
  );

  String? basis(String name) => estimator.estimate(name)?.basis;
  double? kcal(String name) => estimator.estimate(name)?.kcal;

  test('your own food first, by name or alias', () {
    expect((kcal('chicken rice'), basis('chicken rice')), (620, 'from your Chicken rice'));
    expect(kcal('Chix Rice'), 620);
  });

  test('then the common foods table', () {
    expect((kcal('Curry laksa'), basis('Curry laksa')), (590, 'from a typical Laksa'));
  });

  test('a plate with sides goes by its main dish', () {
    expect(basis('Fried rice with chicken cutlet'), 'from a typical Fried rice');
  });

  test('a known name inside a longer one; the longest wins', () {
    expect(basis('Spicy laksa'), 'like a typical Laksa');
    expect(basis('Roast chicken rice set'), 'like your Chicken rice');
  });

  test('a near spelling', () {
    expect(basis('chiken ricee'), 'like your Chicken rice');
  });

  test('nothing to go on gives no estimate', () {
    expect(estimator.estimate('Mystery stew'), isNull);
    expect(estimator.estimate('Zzz'), isNull);
  });
}
