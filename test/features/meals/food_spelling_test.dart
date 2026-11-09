import 'package:daily_rhythm/features/meals/domain/food_spelling.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final spelling = FoodSpelling(FoodSpelling.countWords([
    'Chicken rice',
    'Chicken, broilers, roasted',
    'Laksa',
    'Fried kway teow',
    'Spaghetti bolognese',
    'Thick toast',
  ]));

  test('corrects misspelt words in a dish never logged, keeping case', () {
    expect(spelling.correct('chiken rice'), 'chicken rice');
    expect(spelling.correct('Chiken laksa'), 'Chicken laksa');
    expect(spelling.correct('Spagetti bolognase'), 'Spaghetti bolognese');
  });

  test('leaves known, short and unfinished words alone', () {
    expect(spelling.correct('Chicken rice'), isNull);
    expect(spelling.correct('Milo'), isNull, reason: 'too short to guess');
    expect(spelling.correct('fried chicke', typing: true), isNull, reason: 'still typing the last word');
    expect(spelling.correct('fried chicke'), 'fried chicken');
    expect(spelling.correct('xylophone'), isNull, reason: 'nothing close');
  });

  test('your own words win a tie', () {
    final yours = FoodSpelling(FoodSpelling.countWords(['thick'])).withWords(FoodSpelling.countWords(['thich'], weight: 20));
    expect(yours.correct('thicj'), 'thich');
  });
}
