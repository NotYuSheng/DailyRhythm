import 'dart:convert';

import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/meals/data/services/calorie_lookup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Open Food Facts results prefer per serving, else per 100 g, and skip ones without calories', () async {
    late Uri asked;
    final client = MockClient((request) async {
      asked = request.url;
      return http.Response(jsonEncode({
        'products': [
          {'product_name': 'Instant noodles', 'brands': 'Maggi, Nestle', 'nutriments': {'energy-kcal_serving': 380, 'energy-kcal_100g': 450}},
          {'product_name': 'Curry noodles', 'nutriments': {'energy-kcal_100g': '460'}},
          {'product_name': 'Mystery', 'nutriments': {}},
          {'nutriments': {'energy-kcal_100g': 100}},
        ],
      }), 200);
    });
    final matches = await OpenFoodFactsLookup(client).search('maggi');
    expect(asked.queryParameters['search_terms'], 'maggi');
    expect([for (final m in matches) (m.name, m.brand, m.kcal, m.basis, m.source)], [
      ('Instant noodles', 'Maggi', 380.0, 'serving', 'off'),
      ('Curry noodles', null, 460.0, '100 g', 'off'),
    ]);
  });

  test('a failed lookup is an error, and an empty name asks nothing', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('busy', 503);
    });
    expect(await OpenFoodFactsLookup(client).search('  '), isEmpty);
    expect(calls, 0);
    await expectLater(OpenFoodFactsLookup(client).search('rice'), throwsException);
  });

  test('a meal uses its own calories, else its food\'s times the quantity', () {
    MealEntry meal({int? calories, int? food, int quantity = 1}) => MealEntry(
          date: DateTime(2026, 10, 1), time: DateTime(2026, 10, 1, 12), name: 'x',
          calories: calories, foodItemId: food, quantity: quantity);
    final kcal = {7: 350.0};
    expect(meal(calories: 500, food: 7).caloriesWith(kcal), 500);
    expect(meal(food: 7, quantity: 2).caloriesWith(kcal), 700);
    expect(meal(food: 8).caloriesWith(kcal), isNull);
  });
}
