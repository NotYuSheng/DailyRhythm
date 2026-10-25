import 'package:daily_rhythm/features/exercise/data/models/exercise_item.dart';
import 'package:daily_rhythm/features/health/data/models/health_metric.dart';
import 'package:daily_rhythm/features/journal/data/models/journal_entry.dart';
import 'package:daily_rhythm/features/meals/data/models/food_item.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/shared/models/day_checkin.dart';
import 'package:daily_rhythm/shared/models/daylio_raw_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/repositories/catalog_repository.dart';
import 'package:daily_rhythm/shared/services/database/repositories/checkin_repository.dart';
import 'package:daily_rhythm/shared/services/database/repositories/daylio_raw_repository.dart';
import 'package:daily_rhythm/shared/services/database/repositories/health_repository.dart';
import 'package:daily_rhythm/shared/services/database/repositories/journal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late DatabaseService service;

  setUp(() async => service = await openTestDatabase());
  tearDown(closeTestDatabase);

  group('JournalRepository', () {
    test('saves moments with tags and lists them in time order', () async {
      final repo = JournalRepository(service);
      final day = DateTime(2025, 6, 1);
      await repo.save(JournalEntry(date: day, text: 'no time'));
      await repo.save(JournalEntry(date: day, time: DateTime(2025, 6, 1, 21), text: 'evening', mood: 2));
      final morning = await repo.save(
        JournalEntry(date: DateTime(2025, 6, 1, 9, 30), time: DateTime(2025, 6, 1, 9), text: 'morning', tagIds: [1, 2, 2]),
      );

      final entries = await repo.forDay(day);
      expect(entries.map((e) => e.text), ['morning', 'evening', 'no time']);
      expect(entries.first.id, morning);
      expect(entries.first.date, day, reason: 'date is stored as the day');
      expect(entries.first.tagIds..sort(), [1, 2]);
      expect(entries[1].mood, 2);
    });

    test('updating replaces tags, deleting removes them', () async {
      final repo = JournalRepository(service);
      final day = DateTime(2025, 6, 1);
      final id = await repo.save(JournalEntry(date: day, text: 'a', tagIds: [1, 2]));
      final saved = (await repo.forDay(day)).single;

      await repo.save(saved.copyWith(text: 'b', tagIds: [3]));
      final updated = (await repo.forDay(day)).single;
      expect(updated.id, id);
      expect(updated.text, 'b');
      expect(updated.tagIds, [3]);

      await repo.delete(id);
      expect(await repo.forDay(day), isEmpty);
      final db = await service.database;
      expect(await db.query('journal_entry_tags'), isEmpty);
    });

    test('inRange includes both end days', () async {
      final repo = JournalRepository(service);
      for (final d in [1, 2, 3, 4]) {
        await repo.save(JournalEntry(date: DateTime(2025, 6, d), text: '$d'));
      }
      final entries = await repo.inRange(DateTime(2025, 6, 2), DateTime(2025, 6, 3));
      expect(entries.map((e) => e.text), ['2', '3']);
    });
  });

  group('CheckinRepository', () {
    test('keeps one check-in per day', () async {
      final repo = CheckinRepository(service);
      await repo.save(DayCheckin(date: DateTime(2025, 6, 1, 8), energy: 1));
      await repo.save(DayCheckin(date: DateTime(2025, 6, 1, 22), energy: -1, stress: 2, plantOverride: 'cactus'));

      final checkin = await repo.forDay(DateTime(2025, 6, 1));
      expect(checkin!.energy, -1);
      expect(checkin.stress, 2);
      expect(checkin.plantOverride, 'cactus');
      expect(await repo.inRange(DateTime(2025, 1, 1), DateTime(2025, 12, 31)), hasLength(1));
      expect(await repo.forDay(DateTime(2025, 6, 2)), isNull);
    });

    test('update changes only the given fields', () async {
      final repo = CheckinRepository(service);
      final day = DateTime(2025, 6, 1);
      await Future.wait([repo.update(day, energy: 1), repo.update(day, stress: -2)]);
      await repo.update(day, plantOverride: 'fern');
      var checkin = (await repo.forDay(day))!;
      expect((checkin.energy, checkin.stress, checkin.plantOverride), (1, -2, 'fern'));

      await repo.update(day, clearPlant: true);
      checkin = (await repo.forDay(day))!;
      expect((checkin.energy, checkin.plantOverride), (1, null));
    });

    test('rejects ratings outside -2..2', () {
      expect(() => DayCheckin(date: DateTime(2025, 6, 1), focus: 3), throwsRangeError);
    });
  });

  group('CatalogRepository', () {
    test('finds foods by name or alias, ignoring case', () async {
      final repo = CatalogRepository(service);
      final id = await repo.saveFood(FoodItem(name: 'Mixed rice', aliases: ['Cai peng', 'economy rice']));

      expect((await repo.findFood('mixed RICE'))?.id, id);
      expect((await repo.findFood('cai peng'))?.id, id);
      expect(await repo.findFood('cai'), isNull, reason: 'alias match is whole-word, not a prefix');
    });

    test('saving the same name merges aliases and keeps known values', () async {
      final repo = CatalogRepository(service);
      final id = await repo.saveFood(FoodItem(name: 'Maggi', aliases: ['Maggie'], lastPrice: 1.2));
      final again = await repo.saveFood(FoodItem(name: 'maggi', aliases: ['Magi'], kcal: 380, kcalSource: 'user'));

      expect(again, id);
      final food = (await repo.findFood('Maggi'))!;
      expect(food.aliases, ['Maggie', 'Magi']);
      expect(food.kcal, 380);
      expect(food.lastPrice, 1.2);
    });

    test('search puts prefix matches first, then the most logged', () async {
      final repo = CatalogRepository(service);
      final rice = await repo.saveFood(FoodItem(name: 'Chicken rice'));
      await repo.saveFood(FoodItem(name: 'Rice bowl'));
      await repo.saveFood(FoodItem(name: 'Fried rice'));
      for (var i = 0; i < 3; i++) {
        await service.createMealEntry(
          MealEntry(date: DateTime(2025, 6, 1), time: DateTime(2025, 6, 1, 12), name: 'Chicken rice', foodItemId: rice),
        );
      }

      expect((await repo.searchFoods('rice')).map((f) => f.name), ['Rice bowl', 'Chicken rice', 'Fried rice']);
      expect((await repo.searchFoods('')).first.name, 'Chicken rice');
      expect(await repo.searchFoods('100%'), isEmpty);
    });

    test('exercises work the same way', () async {
      final repo = CatalogRepository(service);
      await repo.saveExercise(ExerciseItem(name: 'Chin ups', aliases: ['chinups']));
      await repo.saveExercise(ExerciseItem(name: 'Run', category: ExerciseItem.cardio));

      expect((await repo.findExercise('CHINUPS'))?.name, 'Chin ups');
      expect((await repo.searchExercises('chin')).single.name, 'Chin ups');
      expect((await repo.findExercise('run'))?.category, ExerciseItem.cardio);
    });
  });

  group('HealthRepository', () {
    test('prefers the Garmin export over other sources per metric', () async {
      final repo = HealthRepository(service);
      final day = DateTime(2025, 6, 1);
      await repo.saveMetrics([
        HealthMetric(date: day, metric: 'steps', value: 9000, source: HealthSource.healthConnect),
        HealthMetric(date: day, metric: 'steps', value: 9500, source: HealthSource.garminExport),
        HealthMetric(date: DateTime(2025, 6, 1, 23), metric: 'resting_hr', value: 52, source: HealthSource.manual),
      ]);

      final metrics = await repo.forDay(day);
      expect(metrics['steps']!.value, 9500);
      expect(metrics['resting_hr']!.value, 52);
    });

    test('saving again replaces the value from that source', () async {
      final repo = HealthRepository(service);
      final day = DateTime(2025, 6, 1);
      await repo.saveMetrics([HealthMetric(date: day, metric: 'steps', value: 100, source: HealthSource.manual)]);
      await repo.saveMetrics([HealthMetric(date: day, metric: 'steps', value: 200, source: HealthSource.manual)]);
      expect((await repo.forDay(day))['steps']!.value, 200);
    });

    test('series gives one value per day in date order', () async {
      final repo = HealthRepository(service);
      await repo.saveMetrics([
        for (final d in [3, 1, 2])
          HealthMetric(date: DateTime(2025, 6, d), metric: 'stress_avg', value: d * 10.0, source: HealthSource.garminExport),
        HealthMetric(date: DateTime(2025, 6, 2), metric: 'stress_avg', value: 99, source: HealthSource.healthConnect),
      ]);
      final series = await repo.series('stress_avg', DateTime(2025, 6, 1), DateTime(2025, 6, 2));
      expect(series.map((m) => m.value), [10, 20]);
    });

    test('workouts are unique per start time and source', () async {
      final repo = HealthRepository(service);
      final start = DateTime(2025, 6, 1, 7, 15);
      await repo.saveWorkouts([
        HealthWorkout(start: start, type: 'running', durationMin: 30, source: HealthSource.garminExport),
        HealthWorkout(start: start, type: 'running', durationMin: 31, source: HealthSource.garminExport),
        HealthWorkout(start: start, type: 'running', durationMin: 30, source: HealthSource.healthConnect),
      ]);
      final workouts = await repo.workoutsInRange(DateTime(2025, 6, 1), DateTime(2025, 6, 1));
      expect(workouts, hasLength(2));
      expect(workouts.firstWhere((w) => w.source == HealthSource.garminExport).durationMin, 31);
    });
  });

  group('DaylioRawRepository', () {
    test('stores entries once', () async {
      final repo = DaylioRawRepository(service);
      final entry = DaylioRawEntry(date: DateTime(2025, 6, 1), loggedTime: '22:10', mood: 3, note: 'Wake 8am');
      await repo.saveAll([entry, entry]);
      await repo.saveAll([entry, DaylioRawEntry(date: DateTime(2025, 6, 1), loggedTime: '09:00')]);

      final rows = await repo.forDay(DateTime(2025, 6, 1));
      expect(rows.map((r) => r.loggedTime), ['09:00', '22:10']);
      expect(rows.last.note, 'Wake 8am');
    });
  });
}
