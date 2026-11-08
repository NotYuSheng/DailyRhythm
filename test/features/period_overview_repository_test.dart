import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/metrics/data/models/period_overview.dart';
import 'package:daily_rhythm/features/metrics/data/services/period_overview_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  tearDown(closeTestDatabase);

  test('every day with meals logged counts its calories', () async {
    final db = await openTestDatabase();
    final full = DateTime(2025, 3, 3), partial = DateTime(2025, 3, 4);
    for (var i = 0; i < 3; i++) {
      await db.createMealEntry(MealEntry(date: full, time: full, name: 'Meal $i', calories: 600));
    }
    await db.createMealEntry(MealEntry(date: partial, time: partial, name: 'Lunch', calories: 700));

    final o = await PeriodOverviewRepository(db).load(OverviewScale.week, full, DateTime(2025, 3, 9), today: DateTime(2026));
    final days = o.grid.single.cells;
    expect((days[0]!.kcal, days[1]!.kcal), (1800, 700), reason: 'one meal logged is still a day of calories');
    expect(o.rows.map((r) => r.kcal), [1800, 700]);
  });
}
