import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/schema_v20.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  setUp(() async => db = await openTestDatabase());
  tearDown(closeTestDatabase);
  final day = DateTime(2026, 11, 10);

  test('foods already logged are meals; running it again changes nothing', () async {
    final raw = await db.database;
    await raw.insert('meal_entries', {'date': day.toIso8601String(), 'time': day.toIso8601String(), 'name': 'Laksa'});
    await SchemaV20.apply(raw);
    final laksa = (await db.getMealEntriesByDate(day)).single;
    expect((laksa.kind, laksa.sideOf), (MealKind.meal, null));
  });

  test('a side moves with its meal and goes when it is deleted', () async {
    final main = await db.createMealEntry(MealEntry(date: day, time: DateTime(2026, 11, 10, 12), name: 'McFillet'));
    final side = await db.createMealEntry(MealEntry(date: day, time: DateTime(2026, 11, 10, 12), name: 'McWings', sideOf: main));
    final other = await db.createMealEntry(MealEntry(date: day, time: DateTime(2026, 11, 10, 9), name: 'Kaya Toast'));

    final next = DateTime(2026, 11, 11);
    await db.updateMealEntry((await db.getMealEntry(main))!.copyWith(date: next, time: DateTime(2026, 11, 11, 20), kind: MealKind.snack));
    final moved = (await db.getMealEntry(side))!;
    expect((moved.date, moved.time, moved.kind), (next, DateTime(2026, 11, 11, 20), MealKind.snack));

    await db.deleteMealEntry(main);
    expect(await db.getMealEntry(side), isNull);
    expect(await db.getMealEntry(other), isNotNull);
  });
}
