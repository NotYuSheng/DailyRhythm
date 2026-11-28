import 'package:daily_rhythm/features/meals/data/models/food_item.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/repositories/catalog_repository.dart';
import 'package:daily_rhythm/shared/services/database/schema_v22.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  setUp(() async => db = await openTestDatabase());
  tearDown(closeTestDatabase);

  test('foods start without a brand; running it again changes nothing', () async {
    final raw = await db.database;
    await raw.insert('food_items', {'name': 'Laksa'});
    await SchemaV22.apply(raw);
    expect((await CatalogRepository(db).findFood('Laksa'))!.brand, isNull);
  });

  test('a brand is kept when left out, and cleared when blank', () async {
    final catalog = CatalogRepository(db);
    await catalog.saveFood(FoodItem(name: 'McSpicy', brand: 'McDonald’s'));
    await catalog.saveFood(FoodItem(name: 'McSpicy', lastPrice: 6.5));
    expect((await catalog.findFood('McSpicy'))!.brand, 'McDonald’s');
    await catalog.saveFood(FoodItem(name: 'McSpicy', brand: ''));
    expect((await catalog.findFood('McSpicy'))!.brand, isNull);
  });
}
