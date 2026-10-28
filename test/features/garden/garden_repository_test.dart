import 'package:daily_rhythm/features/exercise/data/models/exercise_entry.dart';
import 'package:daily_rhythm/features/garden/data/garden_repository.dart';
import 'package:daily_rhythm/features/garden/domain/plant.dart';
import 'package:daily_rhythm/features/health/data/models/health_metric.dart';
import 'package:daily_rhythm/features/journal/data/models/journal_entry.dart';
import 'package:daily_rhythm/features/meals/data/models/food_item.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/sleep/data/models/sleep_entry.dart';
import 'package:daily_rhythm/shared/models/activity_entry.dart';
import 'package:daily_rhythm/shared/models/day_checkin.dart';
import 'package:daily_rhythm/shared/models/mood_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/repositories/catalog_repository.dart';
import 'package:daily_rhythm/shared/services/database/repositories/checkin_repository.dart';
import 'package:daily_rhythm/shared/services/database/repositories/health_repository.dart';
import 'package:daily_rhythm/shared/services/database/repositories/journal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  final day = DateTime(2026, 10, 20);

  setUp(() async => db = await openTestDatabase());
  tearDown(closeTestDatabase);

  Future<int> tagId(String name) async => (await db.getAllTags()).firstWhere((t) => t.name == name).id!;

  test('gathers each table into the day’s plant', () async {
    await db.createActivityEntry(ActivityEntry(date: day, timestamp: day, tagId: await tagId('Study')));
    await db.createActivityEntry(ActivityEntry(date: day, timestamp: day, tagId: await tagId('Class')));
    await db.saveSleepEntry(SleepEntry(date: day.subtract(const Duration(days: 1)), sleepTime: DateTime(2026, 10, 19, 23)));
    await db.saveSleepEntry(SleepEntry(date: day, wakeUpTime: DateTime(2026, 10, 20, 7, 30)));
    for (final name in ['Situps', 'Pushups', 'Situps']) {
      await db.createExerciseEntry(ExerciseEntry(date: day, timestamp: day, type: ExerciseType.weightLifting, exerciseName: name));
    }
    await db.upsertMoodEntry(MoodEntry(date: day, timestamp: day, moodLevel: 3, emoji: ''));
    await JournalRepository(db).save(JournalEntry(date: day, text: 'Lovely lunch', mood: 5));

    final g = (await GardenRepository(db).daysInRange(day, day)).single;
    expect(g.plant.species, PlantSpecies.sprout, reason: 'study and exercise: a bit of everything');
    expect(g.detail, 'A mix: Study, Class and exercise.');
    expect(g.effort, 1, reason: 'three sets with no reps: light');
  });

  test('watch data fills sleep and movement; a pick overrides the plant', () async {
    await HealthRepository(db).saveMetrics([
      HealthMetric(date: day, metric: 'sleep_minutes', value: 330, source: HealthSource.garminExport),
      HealthMetric(date: day, metric: 'steps', value: 13000, source: HealthSource.garminExport),
      HealthMetric(date: day, metric: 'intensity_minutes', value: 30, source: HealthSource.garminExport),
    ]);
    await HealthRepository(db).saveWorkouts([
      HealthWorkout(start: DateTime(2026, 10, 20, 18), type: 'running', source: HealthSource.garminExport),
    ]);
    await CheckinRepository(db).save(DayCheckin(date: day, plantOverride: 'tulip'));

    final g = (await GardenRepository(db).daysInRange(day, day)).single;
    expect(g.detail, 'You picked this plant.');
    expect(g.effort, 4, reason: 'a watch workout with 30 intensity minutes');
    expect((g.plant.species, g.chosen, g.plant.logged), (PlantSpecies.tulip, true, true));
  });

  test('tags logged on most of the weeks before the month count as routine', () async {
    final work = await tagId('Work');
    final month = DateTime(day.year, day.month);
    for (var i = 1; i <= 20; i++) {
      final d = DateTime(month.year, month.month, month.day - i);
      await db.createActivityEntry(ActivityEntry(date: d, timestamp: d, tagId: work));
    }
    await db.createActivityEntry(ActivityEntry(date: day, timestamp: day, tagId: work));
    await db.createActivityEntry(ActivityEntry(date: day, timestamp: day, tagId: await tagId('Family Time')));

    final g = (await GardenRepository(db).daysInRange(day, day)).single;
    expect(g.plant.species, PlantSpecies.tulip);
  });

  test('a day gets the same plant on its own as in its month', () async {
    final work = await tagId('Work');
    final month = DateTime(day.year, day.month);
    // Work becomes routine during the month, not before it.
    for (var d = month; !d.isAfter(day); d = DateTime(d.year, d.month, d.day + 1)) {
      await db.createActivityEntry(ActivityEntry(date: d, timestamp: d, tagId: work));
    }
    final alone = (await GardenRepository(db).daysInRange(day, day)).single;
    final inMonth = (await GardenRepository(db).daysInRange(month, DateTime(month.year, month.month + 1, 0)))
        .firstWhere((g) => g.date == day);
    expect(alone.plant.species, inMonth.plant.species);
  });

  test('returns every day in the range, empty ones included', () async {
    await db.upsertMoodEntry(MoodEntry(date: DateTime(2026, 10, 2), timestamp: DateTime(2026, 10, 2), moodLevel: 4, emoji: ''));
    final days = await GardenRepository(db).daysInRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
    expect(days, hasLength(31));
    expect(days.where((d) => d.plant.logged).map((d) => d.date), [DateTime(2026, 10, 2)]);
  });

  test('a day’s health score uses the categories set for a meal, then its food, then the name', () async {
    final rice = await CatalogRepository(db).saveFood(FoodItem(name: 'Mixed rice', healthTags: ['vegetables']));
    await db.createMealEntry(MealEntry(date: day, time: day, name: 'Mixed rice', foodItemId: rice, calories: 500));
    var g = (await GardenRepository(db).daysInRange(day, day)).single;
    expect(g.diet, 4, reason: 'the food is tagged with vegetables');

    final next = DateTime(day.year, day.month, day.day + 1);
    await db.createMealEntry(MealEntry(date: next, time: next, name: 'Mixed rice', foodItemId: rice, calories: 500, healthTags: ['fried']));
    g = (await GardenRepository(db).daysInRange(next, next)).single;
    expect(g.diet, 2, reason: 'this meal was fried, whatever the food usually is');
  });
}
