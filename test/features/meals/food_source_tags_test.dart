import 'package:daily_rhythm/features/ai/data/ai_client.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/meals/data/services/food_source_tags.dart';
import 'package:daily_rhythm/features/tags/data/models/tag.dart';
import 'package:daily_rhythm/shared/models/activity_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  setUp(() async => db = await openTestDatabase());
  tearDown(closeTestDatabase);

  Future<int> tag(String name) async {
    final existing = (await db.getAllTags()).where((t) => t.name == name).firstOrNull;
    return existing?.id ?? await db.createTag(Tag(name: name, emoji: 'tag', category: 'Food', kind: TagKind.foodSource));
  }

  Future<void> tagDay(DateTime day, String name) async =>
      db.createActivityEntry(ActivityEntry(date: day, timestamp: day, tagId: await tag(name)));

  Future<int> meal(DateTime day, String name, {int hour = 12, String? source}) =>
      db.createMealEntry(MealEntry(date: day, time: DateTime(day.year, day.month, day.day, hour), name: name, foodSource: source));

  test('old tag names map to meal sources; Supplement has none', () {
    expect(FoodSourceTags.sourceFor('Fast Food'), FoodSource.fastFood);
    expect(FoodSourceTags.sourceFor('Free Food'), FoodSource.free);
    expect(FoodSourceTags.sourceFor('Supplement'), isNull);
  });

  test('only matches tagged on that day, for meals of that day, are kept', () {
    const days = [
      SourceDay(date: '2026-03-04', sources: {'takeout', 'fast_food'}, meals: [SourcelessMeal(id: 1, name: 'Kaya Toast'), SourcelessMeal(id: 2, name: 'McSpicy')]),
    ];
    final picks = FoodSourceTags.parse('Here: {"meals": {"2": "fast_food", "1": "delivery", "9": "takeout"}}', days);
    expect(picks, {2: 'fast_food'});
    expect(() => FoodSourceTags.parse('no idea', days), throwsA(isA<AiException>()));
  });

  test('the obvious days move without the AI, and every food-source tag goes', () async {
    final mon = DateTime(2026, 3, 2), tue = DateTime(2026, 3, 3), wed = DateTime(2026, 3, 4);
    await tagDay(mon, 'Takeout');
    final chickenRice = await meal(mon, 'Chicken Rice');
    await tagDay(tue, 'Fast Food');
    await meal(tue, 'Toast', hour: 8);
    await meal(tue, 'McSpicy');
    await tagDay(wed, 'Supplement');
    final already = await meal(wed, 'Laksa', source: FoodSource.foodCourt);

    final days = await FoodSourceTags(db).days();
    expect(days.map((d) => d.date), ['2026-03-02', '2026-03-03'], reason: 'Supplement moves nowhere');
    expect(FoodSourceTags.unclear(days).single.date, '2026-03-03');

    final result = await FoodSourceTags(db).run();
    expect(result.mealsSet, 1);
    expect(result.daysSkipped, 1);
    final meals = {for (final d in [mon, tue, wed]) for (final m in await db.getMealEntriesByDate(d)) m.id: m.foodSource};
    expect(meals[chickenRice], FoodSource.takeout);
    expect(meals[already], FoodSource.foodCourt);
    expect((await db.getAllTags()).where((t) => t.kind == TagKind.foodSource), isEmpty);
    expect(await FoodSourceTags(db).any(), isFalse);
  });
}
