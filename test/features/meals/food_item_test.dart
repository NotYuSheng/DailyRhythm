import 'package:daily_rhythm/features/exercise/data/models/exercise_item.dart';
import 'package:daily_rhythm/features/meals/data/models/food_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a blank, missing or plain-text aliases field still reads', () {
    for (final stored in ['', '  ', null]) {
      expect(FoodItem.fromMap({'id': 1, 'name': 'Pizza', 'aliases': stored}).aliases, isEmpty);
    }
    expect(FoodItem.fromMap({'id': 1, 'name': 'Pizza', 'aliases': '["pizza slice"]'}).aliases, ['pizza slice']);
    expect(FoodItem.fromMap({'id': 1, 'name': 'Pizza', 'aliases': 'pizza slice; pizza'}).aliases, ['pizza slice', 'pizza'],
        reason: 'plain text from an older tool');
  });

  test('exercise items read a blank aliases field too', () {
    final x = ExerciseItem.fromMap({'id': 1, 'name': 'Dips', 'aliases': '', 'category': 'strength'});
    expect(x.aliases, isEmpty);
  });
}
