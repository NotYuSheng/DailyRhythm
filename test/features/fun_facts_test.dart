import 'package:daily_rhythm/features/exercise/data/models/exercise_entry.dart';
import 'package:daily_rhythm/features/health/data/models/health_metric.dart';
import 'package:daily_rhythm/features/journal/data/models/journal_entry.dart';
import 'package:daily_rhythm/features/meals/data/models/food_item.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/metrics/data/models/metric_data.dart';
import 'package:daily_rhythm/features/metrics/data/services/fun_facts_service.dart';
import 'package:daily_rhythm/features/sleep/data/models/sleep_entry.dart';
import 'package:daily_rhythm/shared/models/activity_entry.dart';
import 'package:daily_rhythm/shared/models/mood_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/repositories/catalog_repository.dart';
import 'package:daily_rhythm/shared/services/database/repositories/health_repository.dart';
import 'package:daily_rhythm/shared/services/database/repositories/journal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  // March 2026: the 2nd, 9th, 16th, 23rd and 30th are Mondays.
  final march = DateRange(start: DateTime(2026, 3, 1), end: DateTime(2026, 3, 31), label: 'March');

  setUp(() async => db = await openTestDatabase());
  tearDown(closeTestDatabase);

  Future<void> meal(int day, String name, {double? price}) async {
    final id = await CatalogRepository(db).saveFood(FoodItem(name: name));
    await db.createMealEntry(MealEntry(date: DateTime(2026, 3, day), time: DateTime(2026, 3, day, 12), name: name, price: price, foodItemId: id));
  }

  Map<String, FunFact> byTitle(List<FunFact> facts) => {for (final f in facts) f.title: f};

  test('food facts: go-to, new foods, biggest treat, weekday habit', () async {
    await meal(2, 'Chicken rice', price: 4); // earlier ones make it not new
    for (final d in [2, 9, 16, 23]) {
      await meal(d, 'Wing rice', price: 5);
    }
    await meal(5, 'Chicken rice', price: 4.5);
    await meal(12, 'Wagyu don', price: 28);
    await meal(20, 'Chicken rice', price: 4);
    final id = (await CatalogRepository(db).findFood('Chicken rice'))!.id;
    await db.createMealEntry(MealEntry(date: DateTime(2026, 2, 1), time: DateTime(2026, 2, 1), name: 'Chicken rice', foodItemId: id));

    final facts = byTitle(await FunFactsService(db).factsFor(march, today: DateTime(2026, 3, 31)));
    expect(facts['Go-to food']!.value, anyOf('Wing rice', 'Chicken rice'));
    expect(facts['New foods tried']!.value, '2', reason: 'Wing rice and Wagyu don; Chicken rice was eaten in February');
    expect(facts['Biggest treat']!.value, '\$28.00');
    expect(facts['Biggest treat']!.detail, contains('Wagyu don, 12 Mar'));
    expect((facts['Mondays are for']!.value, facts['Mondays are for']!.detail), ('Wing rice', '4 of 4 times on a Monday'));
  });

  test('movement and sleep records', () async {
    await HealthRepository(db).saveMetrics([
      for (var d = 1; d <= 31; d++)
        HealthMetric(date: DateTime(2026, 3, d), metric: 'steps', value: 10000, source: HealthSource.garminExport),
    ]);
    for (final (d, reps) in [(3, 40), (4, 60)]) {
      await db.createExerciseEntry(ExerciseEntry(
        date: DateTime(2026, 3, d), timestamp: DateTime(2026, 3, d), type: ExerciseType.weightLifting,
        exerciseName: 'Sit ups', reps: reps, sets: 1));
    }
    await db.saveSleepEntry(SleepEntry(date: DateTime(2026, 3, 1), sleepTime: DateTime(2026, 3, 1, 23)));
    for (var d = 2; d <= 7; d++) {
      await db.saveSleepEntry(SleepEntry(date: DateTime(2026, 3, d), wakeUpTime: DateTime(2026, 3, d, d == 4 ? 9 : 6, d == 5 ? 10 : 30), sleepTime: DateTime(2026, 3, d, 23)));
    }

    final facts = byTitle(await FunFactsService(db).factsFor(march, today: DateTime(2026, 3, 31)));
    expect(facts['Most reps']!.value, '100');
    expect(facts['Distance on foot']!.value, '233 km', reason: '310,000 steps at 0.75 m');
    expect(facts['Distance on foot']!.detail, startsWith('About 4.7 times Singapore from Tuas to Changi'));
    expect(facts['Longest night']!.value, '10h 30m');
    expect(facts['Longest night']!.detail, contains('Earliest start: 06:10 on 5 Mar'));
  });

  test('logging run, garden mix and quiet periods', () async {
    for (final d in [1, 2, 3, 4, 10]) {
      await db.upsertMoodEntry(MoodEntry(date: DateTime(2026, 3, d), timestamp: DateTime(2026, 3, d), moodLevel: d == 3 ? 5 : 3, emoji: ''));
    }
    final facts = byTitle(await FunFactsService(db).factsFor(march, today: DateTime(2026, 3, 31)));
    expect((facts['Days logged']!.value, facts['Days logged']!.detail), ('5 of 31', 'Longest run: 4 days in a row'));
    expect(facts['The garden grew']!.detail, '5 sprouts, 1 in bloom');

    final quiet = await FunFactsService(db).factsFor(
      DateRange(start: DateTime(2026, 4, 1), end: DateTime(2026, 4, 30), label: 'April'), today: DateTime(2026, 4, 30));
    expect(quiet, isEmpty);
  });

  test('on this day finds the latest earlier year with something logged', () async {
    await JournalRepository(db).save(JournalEntry(date: DateTime(2024, 3, 15), text: 'Beach day'));
    await meal(15, 'Laksa'); // same day this year doesn't count
    final memory = byTitle(await FunFactsService(db).factsFor(march, today: DateTime(2026, 3, 15)))['On this day']!;
    expect((memory.value, memory.detail), ('2 years ago', '“Beach day”'));
  });

  test('distances are compared with something familiar', () {
    expect(distanceComparison(20), 'about 47% of a marathon');
    expect(distanceComparison(42), 'about a marathon');
    expect(distanceComparison(150), 'about 3 times Singapore from Tuas to Changi');
    expect(distanceComparison(330), 'about Singapore to Kuala Lumpur');
  });

  test('a line\'s price is its total, whatever the quantity', () async {
    for (var d = 1; d <= 5; d++) {
      await db.createMealEntry(MealEntry(date: DateTime(2026, 3, d), time: DateTime(2026, 3, d, 12), name: 'Kopi', price: 3, quantity: 2));
    }
    final facts = byTitle(await FunFactsService(db).factsFor(march, today: DateTime(2026, 3, 31)));
    expect(facts['Biggest treat']!.detail, endsWith('\$15.00 on food in all'));
  });

  test('nights just under an hour round up, and work days grow cacti', () async {
    for (var d = 2; d <= 6; d++) {
      // An imported total, not one worked out from whole minutes.
      await db.upsertSleepEntry(SleepEntry(date: DateTime(2026, 3, d), wakeUpTime: DateTime(2026, 3, d, 7), totalHours: d == 2 ? 7.995 : 7));
    }
    final work = (await db.getAllTags()).firstWhere((t) => t.name == 'Work');
    for (var d = 10; d <= 12; d++) {
      await db.createActivityEntry(ActivityEntry(date: DateTime(2026, 3, d), timestamp: DateTime(2026, 3, d), tagId: work.id!));
    }
    final facts = byTitle(await FunFactsService(db).factsFor(march, today: DateTime(2026, 3, 31)));
    expect(facts['Longest night']!.value, '8h 0m');
    expect(facts['The garden grew']!.detail, contains('3 cacti'));
  });
}
