import 'package:daily_rhythm/features/meals/data/models/food_item.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/repositories/catalog_repository.dart';
import 'package:daily_rhythm/shared/services/database/schema_v18.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  setUp(() async => db = await openTestDatabase());
  tearDown(closeTestDatabase);
  final day = DateTime(2026, 11, 10);

  Future<int> meal(String name, int foodId) =>
      db.createMealEntry(MealEntry(date: day, time: day, name: name, quantity: 1, foodItemId: foodId));

  test('names are tidied, look-alikes merged and unused items removed', () async {
    final raw = await db.database;
    final a = await raw.insert('food_items', {'name': 'mixed rice', 'aliases': '["cai fan"]'});
    final b = await raw.insert('food_items', {'name': 'Mixed  rice', 'aliases': '[]'});
    final unused = await raw.insert('food_items', {'name': 'Chiken rice', 'aliases': '[]'});
    await meal('mixed rice', a);
    await meal('Mixed  rice', b);

    await SchemaV18.apply(raw);
    await SchemaV18.apply(raw);

    final foods = await raw.query('food_items');
    expect([for (final f in foods) f['name']], ['Mixed Rice']);
    expect(foods.single['id'], a, reason: 'the later look-alike joined the earlier');
    expect(FoodItem.fromMap(foods.single).aliases, containsAll(['cai fan', 'Mixed  rice']));
    expect({for (final m in await raw.query('meal_entries')) (m['name'], m['food_item_id'])}, {('Mixed Rice', a)});
    expect(await raw.query('food_items', where: 'id = ?', whereArgs: [unused]), isEmpty);
  });

  test('renaming a meal folds the old food into the new, keeping its spelling', () async {
    final catalog = CatalogRepository(db);
    final old = await catalog.saveFood(FoodItem(name: 'chiken rice', kcal: 600));
    final id = await meal('Chiken Rice', old);
    final renamed = await catalog.saveFood(FoodItem(name: 'chicken rice'));
    final saved = (await db.getMealEntry(id))!;
    await db.updateMealEntry(saved.copyWith(name: 'Chicken Rice', foodItemId: renamed));

    final foods = [for (final r in await (await db.database).query('food_items')) FoodItem.fromMap(r)];
    expect([for (final f in foods) f.name], ['Chicken Rice'], reason: 'the old food is gone');
    expect(foods.single.aliases, ['Chiken Rice'], reason: 'its spelling is kept for Did you mean');
    expect(foods.single.kcal, 600, reason: 'what it knew carries over');
  });

  test('deleting the last meal of a food removes the food', () async {
    final food = await CatalogRepository(db).saveFood(FoodItem(name: 'Kaya Toast'));
    final id = await meal('Kaya Toast', food);
    await db.deleteMealEntry(id);
    expect(await (await db.database).query('food_items'), isEmpty);
  });
}
