import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  setUp(() async => db = await openTestDatabase());
  tearDown(closeTestDatabase);

  test('a day\'s meals keep the order they were put in; new ones go last', () async {
    final day = DateTime(2026, 11, 10);
    Future<int> meal(String name, int hour) => db.createMealEntry(MealEntry(date: day, time: DateTime(2026, 11, 10, hour), name: name, quantity: 1));
    final toast = await meal('Kaya Toast', 8);
    final rice = await meal('Chicken Rice', 12);
    final laksa = await meal('Laksa', 19);
    Future<List<String>> names() async => [for (final m in await db.getMealEntriesByDate(day)) m.name];
    expect(await names(), ['Kaya Toast', 'Chicken Rice', 'Laksa']);

    await db.reorderMeals([laksa, toast, rice]);
    expect(await names(), ['Laksa', 'Kaya Toast', 'Chicken Rice']);

    await meal('Milo', 7);
    expect(await names(), ['Laksa', 'Kaya Toast', 'Chicken Rice', 'Milo'], reason: 'a new meal goes to the bottom');
  });
}
