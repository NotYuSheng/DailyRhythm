import 'dart:convert';

import 'package:daily_rhythm/features/meals/data/models/food_item.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/tidy/data/tidy_service.dart';
import 'package:daily_rhythm/features/tidy/domain/tidy_item.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/repositories/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  late TidyService tidy;
  final day = DateTime(2026, 10, 14);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await openTestDatabase();
    tidy = TidyService(db);
  });
  tearDown(closeTestDatabase);

  Future<int> meal(String name, {int hour = 12, int minute = 0, double? price, int? foodId}) =>
      db.createMealEntry(MealEntry(date: day, time: DateTime(2026, 10, 14, hour, minute), name: name, price: price, foodItemId: foodId));

  test('finds a side logged on its own, a double entry and a missing usual price', () async {
    final laksaFood = await CatalogRepository(db).saveFood(FoodItem(name: 'Laksa', lastPrice: 5));
    final burger = await meal('McSpicy', price: 6.5);
    await meal('Fries', minute: 3);
    await meal('Laksa', hour: 19, foodId: laksaFood);
    await meal('Laksa', hour: 19, minute: 1, foodId: laksaFood, price: 5);
    final report = await tidy.check(day, day);
    expect([for (final f in report.fixes) (f.type, f.name, f.mainId)], [(TidyFix.sideType, 'Fries', burger)]);
    expect([for (final f in report.flags) f.reason], containsAll(['Logged twice?', 'No price; usually \$5.00']));

    await tidy.dismiss([report.fixes.single.key]);
    expect((await tidy.check(day, day)).fixes, isEmpty, reason: 'dismissed stays dismissed');
  });

  test('a suggestions file applies: brand, snack, split and side', () async {
    final chop = await meal('Chicken chop w coleslaw', price: 9);
    final kopi = await meal('Kopi', hour: 15);
    final burger = await meal('McSpicy', hour: 19);
    final wings = await meal('McWings', hour: 19, minute: 2);
    final gone = await meal('Renamed since', hour: 20);
    await db.updateMealEntry((await db.getMealEntry(gone))!.copyWith(name: 'Something else'));
    final file = jsonEncode({
      'fixes': [
        {'type': 'split', 'meal': chop, 'name': 'Chicken chop w coleslaw', 'parts': ['Chicken chop', 'Coleslaw']},
        {'type': 'kind', 'meal': kopi, 'name': 'Kopi', 'kind': 'snack'},
        {'type': 'side', 'meal': wings, 'name': 'McWings', 'of': burger, 'ofName': 'McSpicy'},
        {'type': 'brand', 'name': 'McSpicy', 'brand': 'McDonald’s'},
        {'type': 'kind', 'meal': gone, 'name': 'Renamed since', 'kind': 'snack'},
        {'type': 'nonsense'},
      ],
    });
    final fixes = await tidy.load(file);
    expect(fixes.length, 4, reason: 'the renamed meal and the nonsense are left out');
    await CatalogRepository(db).saveFood(FoodItem(name: 'McSpicy'));
    expect(await tidy.apply(fixes), 4);

    final meals = await db.getMealEntriesByDate(day);
    final main = meals.firstWhere((m) => m.id == chop);
    final side = meals.firstWhere((m) => m.sideOf == chop);
    expect((main.name, main.price, side.name, side.price), ('Chicken Chop', 9.0, 'Coleslaw', null));
    expect(meals.firstWhere((m) => m.id == kopi).kind, MealKind.snack);
    final w = meals.firstWhere((m) => m.id == wings);
    expect((w.sideOf, w.time), (burger, DateTime(2026, 10, 14, 19)));
    expect((await CatalogRepository(db).findFood('McSpicy'))!.brand, 'McDonald’s');
    expect(await CatalogRepository(db).findFood('Chicken chop w coleslaw'), isNull, reason: 'the old food goes');
  });
}
