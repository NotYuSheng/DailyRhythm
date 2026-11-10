import 'package:daily_rhythm/shared/utils/name_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('food and exercise names are tidied to Title Case, brands kept', () {
    expect(tidyName('mixed rice'), 'Mixed Rice');
    expect(tidyName('  NASI   lemak '), 'Nasi Lemak');
    expect(tidyName('CHICKEN RICE'), 'Chicken Rice');
    expect(tidyName('rice with egg'), 'Rice with Egg');
    expect(tidyName('with egg'), 'With Egg', reason: 'first word always capitalised');
    expect(tidyName('KFC zinger'), 'KFC Zinger');
    expect(tidyName('McChicken muffin'), 'McChicken Muffin');
    expect(tidyName('bbq pork'), 'Bbq Pork', reason: 'lower case gives no hint of a brand');
    expect(tidyName('BBQ pork'), 'BBQ Pork');
    expect(tidyName('7-eleven onigiri'), '7-eleven Onigiri');
    expect(tidyName('stir-fry vegetables'), 'Stir-Fry Vegetables');
    expect(tidyName("old chang kee's curry puff"), "Old Chang Kee's Curry Puff");
    expect(tidyName('dumbbell curl to overhead press'), 'Dumbbell Curl to Overhead Press');
    expect(tidyName('(large) fries'), '(Large) Fries');
  });
}
