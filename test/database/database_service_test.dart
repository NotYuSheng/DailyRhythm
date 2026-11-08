import 'package:daily_rhythm/features/journal/data/models/journal_entry.dart';
import 'package:daily_rhythm/features/exercise/data/models/exercise_entry.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/sleep/data/models/sleep_entry.dart';
import 'package:daily_rhythm/features/tags/data/models/tag.dart';
import 'package:daily_rhythm/shared/models/activity_entry.dart';
import 'package:daily_rhythm/shared/models/mood_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/repositories/journal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late DatabaseService db;

  setUp(() async => db = await openTestDatabase());
  tearDown(closeTestDatabase);

  group('dates', () {
    test('entries saved with a time of day are found on their day', () async {
      await db.createExerciseEntry(ExerciseEntry(
        date: DateTime(2026, 10, 20, 18, 42),
        timestamp: DateTime(2026, 10, 20, 18, 42),
        type: ExerciseType.weightLifting,
        exerciseName: 'Push up',
        equipmentType: EquipmentType.bodyweight,
        reps: 20,
        sets: 3,
      ));

      final found = await db.getExerciseEntriesByDate(DateTime(2026, 10, 20));
      expect(found.single.date, DateTime(2026, 10, 20));
      expect(await db.getExerciseEntriesByDate(DateTime(2026, 10, 21)), isEmpty);
    });

    test('activities are found by day regardless of query time', () async {
      final tag = (await db.getAllTags()).first;
      await db.createActivityEntry(ActivityEntry(
        date: DateTime(2026, 10, 20, 9),
        timestamp: DateTime(2026, 10, 20, 9),
        tagId: tag.id!,
      ));
      expect(await db.getActivityEntriesByDate(DateTime(2026, 10, 20, 23, 59)), hasLength(1));
    });
  });

  group('sleep', () {
    Future<SleepEntry?> day(int d) => db.getSleepEntryByDate(DateTime(2026, 10, d));

    test('total runs from the previous day bedtime to this day wake time', () async {
      await db.saveSleepEntry(SleepEntry(
        date: DateTime(2026, 10, 19),
        wakeUpTime: DateTime(2026, 10, 19, 7),
        sleepTime: DateTime(2026, 10, 19, 0, 45), // after midnight
      ));
      final total = await db.saveSleepEntry(SleepEntry(
        date: DateTime(2026, 10, 20),
        wakeUpTime: DateTime(2026, 10, 20, 7),
        sleepTime: DateTime(2026, 10, 20, 23),
      ));
      expect(total, 6.25);
      expect((await day(20))!.totalHours, 6.25);
    });

    test('is unknown when the previous bedtime is missing', () async {
      final total = await db.saveSleepEntry(SleepEntry(
        date: DateTime(2026, 10, 20),
        wakeUpTime: DateTime(2026, 10, 20, 7),
        sleepTime: DateTime(2026, 10, 20, 23),
      ));
      expect(total, isNull);
    });

    test('editing a past day recomputes the next day without touching its bedtime', () async {
      for (final d in [19, 20, 21]) {
        await db.saveSleepEntry(SleepEntry(
          date: DateTime(2026, 10, d),
          wakeUpTime: DateTime(2026, 10, d, 7),
          sleepTime: DateTime(2026, 10, d, 23),
        ));
      }

      // Go back and change the 20th's bedtime to 1am.
      await db.saveSleepEntry(SleepEntry(
        id: (await day(20))!.id,
        date: DateTime(2026, 10, 20),
        wakeUpTime: DateTime(2026, 10, 20, 7),
        sleepTime: DateTime(2026, 10, 20, 1),
      ));

      final next = (await day(21))!;
      expect(next.totalHours, 6);
      // Previously the 21st's own bedtime was overwritten with the 20th's.
      expect(next.sleepTime!.hour, 23);
    });

    Future<void> threeNights() async {
      for (final d in [19, 20, 21]) {
        await db.saveSleepEntry(SleepEntry(
          date: DateTime(2026, 10, d),
          wakeUpTime: DateTime(2026, 10, d, 7),
          sleepTime: DateTime(2026, 10, d, 23),
        ));
      }
    }

    test('clearing a bedtime makes the next day\'s total unknown', () async {
      await threeNights();
      expect((await day(21))!.totalHours, 8);
      await db.saveSleepEntry(SleepEntry(id: (await day(20))!.id, date: DateTime(2026, 10, 20), wakeUpTime: DateTime(2026, 10, 20, 7)));
      expect((await day(21))!.totalHours, isNull);
    });

    test('deleting a day makes the next day\'s total unknown', () async {
      await threeNights();
      await db.deleteSleepEntry((await day(20))!.id!);
      expect(await day(20), isNull);
      expect((await day(21))!.totalHours, isNull);
      expect((await day(21))!.wakeUpTime, DateTime(2026, 10, 21, 7));
    });

    test('one entry per day', () async {
      for (var i = 0; i < 3; i++) {
        await db.saveSleepEntry(SleepEntry(
          date: DateTime(2026, 10, 20, i),
          wakeUpTime: DateTime(2026, 10, 20, 7),
          sleepTime: DateTime(2026, 10, 20, 23),
        ));
      }
      expect(await db.getAllSleepEntries(), hasLength(1));
    });
  });

  group('meals', () {
    test('price is optional', () async {
      await db.createMealEntry(MealEntry(
        date: DateTime(2026, 10, 20),
        time: DateTime(2026, 10, 20, 15),
        name: 'Apple',
      ));
      final meal = (await db.getMealEntriesByDate(DateTime(2026, 10, 20))).single;
      expect(meal.price, isNull);
    });
  });

  group('mood', () {
    test('upsert keeps a single mood per day', () async {
      for (final level in [3, 2, 4]) {
        await db.upsertMoodEntry(MoodEntry(
          date: DateTime(2026, 10, 20),
          timestamp: DateTime.now(),
          moodLevel: level,
          emoji: '',
        ));
      }
      expect((await db.getAllMoodEntries()).single.moodLevel, 4);
    });
  });

  group('tags', () {
    test('renaming a category moves its tags with it', () async {
      final health = (await db.getAllTagCategories()).firstWhere((c) => c.name == 'Health');
      final healthTags = await db.getTagsByCategory('Health');
      expect(healthTags, isNotEmpty);

      await db.updateTagCategory(health.copyWith(name: 'Symptoms'));

      expect(await db.getTagsByCategory('Health'), isEmpty);
      expect((await db.getTagsByCategory('Symptoms')).length, healthTags.length);
    });

    test('merging tags moves entries and moment links, keeping one per day', () async {
      final hike = await db.createTag(Tag(name: 'Hike', emoji: 'boot', category: 'General'));
      final hiking = await db.createTag(Tag(name: 'Hiking', emoji: 'boot', category: 'General'));
      for (final (d, tag) in [(1, hike), (2, hike), (2, hiking)]) {
        await db.createActivityEntry(ActivityEntry(date: DateTime(2026, 10, d), timestamp: DateTime(2026, 10, d), tagId: tag));
      }
      final repo = JournalRepository(db);
      await repo.save(JournalEntry(date: DateTime(2026, 10, 1), text: 'Hill', tagIds: [hike]));
      await repo.save(JournalEntry(date: DateTime(2026, 10, 2), text: 'Both', tagIds: [hike, hiking]));

      await db.mergeTags(hike, hiking);

      expect(await db.getTag(hike), isNull);
      final entries = await (await db.database).query('activity_entries', orderBy: 'date');
      expect([for (final e in entries) (e['date'], e['tagId'])], [
        (DateTime(2026, 10, 1).toIso8601String(), hiking),
        (DateTime(2026, 10, 2).toIso8601String(), hiking),
      ]);
      expect([for (final m in await repo.inRange(DateTime(2026, 10, 1), DateTime(2026, 10, 2))) m.tagIds], [
        [hiking],
        [hiking],
      ]);
      expect((await db.getTagUseCounts())[hiking], 4);
    });

    test('merging keeps the notes of a day that had both tags', () async {
      final hike = await db.createTag(Tag(name: 'Hike', emoji: 'boot', category: 'General'));
      final hiking = await db.createTag(Tag(name: 'Hiking', emoji: 'boot', category: 'General'));
      final day = DateTime(2026, 10, 3);
      await db.createActivityEntry(ActivityEntry(date: day, timestamp: day, tagId: hike, notes: 'Mt. Faber'));
      await db.createActivityEntry(ActivityEntry(date: day, timestamp: day, tagId: hiking));
      await db.mergeTags(hike, hiking);
      final kept = (await db.getActivityEntriesByDate(day)).single;
      expect((kept.tagId, kept.notes), (hiking, 'Mt. Faber'));
    });

    test('moving tags to an existing group joins it, and empty groups go', () async {
      final a = await db.createTag(Tag(name: 'Hike', emoji: 'x', category: 'Outdoors'));
      await db.createTag(Tag(name: 'Read', emoji: 'x', category: 'Indoors'));
      await db.createTagCategory(TagCategory(name: 'Outdoors'));
      await db.createTagCategory(TagCategory(name: 'Indoors'));
      await db.moveTagsToGroup([a], 'Indoors');
      expect((await db.getTag(a))!.category, 'Indoors');
      final groups = (await db.getAllTagCategories()).map((c) => c.name);
      expect(groups, contains('Indoors'));
      expect(groups, isNot(contains('Outdoors')));
    });

    test('changing a tag\'s kind', () async {
      final id = await db.createTag(Tag(name: 'Coffee', emoji: 'cup', category: 'General'));
      await db.updateTag((await db.getTag(id))!.copyWith(kind: TagKind.foodSource));
      expect((await db.getTag(id))!.kind, TagKind.foodSource);
    });

    test('deleting a tag removes it from moments', () async {
      final tag = await db.createTag(Tag(name: 'Hiking', emoji: 'boot', category: 'General'));
      final repo = JournalRepository(db);
      await repo.save(JournalEntry(date: DateTime(2026, 10, 20), text: 'Hill', tagIds: [tag]));
      await db.deleteTag(tag);
      expect(await (await db.database).query('journal_entry_tags'), isEmpty);
      expect((await repo.forDay(DateTime(2026, 10, 20))).single.text, 'Hill');
    });

    test('deleting a tag deletes its activity entries', () async {
      final tag = await db.createTag(Tag(name: 'Gaming', emoji: 'game_structure', category: 'Hobby'));
      await db.createActivityEntry(ActivityEntry(date: DateTime(2026, 10, 20), timestamp: DateTime(2026, 10, 20), tagId: tag));
      expect(await db.getActivityCountForTag(tag), 1);

      await db.deleteTag(tag);
      expect(await db.getActivityCountForTag(tag), 0);
    });
  });
}
