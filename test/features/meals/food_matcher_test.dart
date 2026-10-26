import 'package:daily_rhythm/features/meals/data/models/food_item.dart';
import 'package:daily_rhythm/features/meals/domain/food_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final matcher = FoodMatcher([
    FoodChoice(FoodItem(id: 1, name: 'Mixed rice', aliases: ['Cai peng', 'economy rice']), 347),
    FoodChoice(FoodItem(id: 2, name: 'Maggi', aliases: ['Maggie']), 108),
    FoodChoice(FoodItem(id: 3, name: 'Chicken rice'), 90),
    FoodChoice(FoodItem(id: 4, name: 'Rice bowl'), 3),
    FoodChoice(FoodItem(id: 5, name: 'Wanton noodles'), 50),
  ]);

  test('suggests name starts, then word starts, then contains, by use', () {
    expect(matcher.suggest('ri').map((f) => f.item.name), ['Rice bowl', 'Mixed rice', 'Chicken rice']);
    expect(matcher.suggest('cai').map((f) => f.item.name), ['Mixed rice'], reason: 'through an alias');
    expect(matcher.suggest(''), isEmpty);
    expect(matcher.suggest('maggi'), isEmpty, reason: 'already typed in full');
  });

  test('offers the agreed name for an alias or a close typo', () {
    expect(matcher.didYouMean('maggie')?.item.name, 'Maggi');
    expect(matcher.didYouMean('Cai Peng')?.item.name, 'Mixed rice');
    expect(matcher.didYouMean('wanton noodle')?.item.name, 'Wanton noodles');
    expect(matcher.didYouMean('chiken rice')?.item.name, 'Chicken rice');
    expect(matcher.didYouMean('Maggi'), isNull, reason: 'already the name');
    expect(matcher.didYouMean('Laksa'), isNull);
    expect(matcher.didYouMean('ma'), isNull, reason: 'too short to guess');
  });

  test('exact matches name or alias, ignoring case and spaces', () {
    expect(matcher.exact('  mixed   RICE ')?.item.id, 1);
    expect(matcher.exact('economy rice')?.item.id, 1);
    expect(matcher.exact('rice'), isNull);
  });

  test('edit distance', () {
    expect(FoodMatcher.editDistance('maggie', 'maggi'), 1);
    expect(FoodMatcher.editDistance('kitten', 'sitting'), 3);
  });
}
