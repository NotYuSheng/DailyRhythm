import 'package:daily_rhythm/features/exercise/data/models/exercise_entry.dart';
import 'package:daily_rhythm/features/metrics/data/models/metric_data.dart';
import 'package:daily_rhythm/features/metrics/data/services/metrics_service.dart';
import 'package:daily_rhythm/features/sleep/data/models/sleep_entry.dart';
import 'package:daily_rhythm/features/tags/data/models/tag.dart';
import 'package:daily_rhythm/shared/models/activity_entry.dart';
import 'package:daily_rhythm/shared/models/mood_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  late MetricsService metrics;
  final range = DateRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 7), label: 'Week');

  setUp(() async {
    db = await openTestDatabase();
    metrics = MetricsService(db);
  });
  tearDown(closeTestDatabase);

  group('DateRange', () {
    test('equal ranges are equal, so provider caches are reused', () {
      expect(DateRange.last7Days(), DateRange.last7Days());
      expect(DateRange.last7Days().hashCode, DateRange.last7Days().hashCode);
      expect(DateRange.last7Days(), isNot(DateRange.last30Days()));
    });

    test('daysCount is inclusive', () {
      expect(range.daysCount, 7);
    });
  });

  group('sleep', () {
    test('averages only days with a known total', () async {
      await db.createSleepEntry(SleepEntry(date: DateTime(2026, 10, 2), totalHours: 6));
      await db.createSleepEntry(SleepEntry(date: DateTime(2026, 10, 3), totalHours: 8));
      // No previous bedtime: unknown, must not count as 0h or a made-up value.
      await db.createSleepEntry(SleepEntry(
        date: DateTime(2026, 10, 4),
        wakeUpTime: DateTime(2026, 10, 4, 7),
        sleepTime: DateTime(2026, 10, 4, 23),
      ));

      final result = await metrics.calculateSleepMetrics(range);
      expect(result.averageHours, 7);
      expect(result.dailyData, hasLength(2));
      expect(result.consistency, 1);
    });

    test('excludes days outside the range', () async {
      await db.createSleepEntry(SleepEntry(date: DateTime(2026, 9, 30), totalHours: 2));
      await db.createSleepEntry(SleepEntry(date: DateTime(2026, 10, 8), totalHours: 2));
      await db.createSleepEntry(SleepEntry(date: DateTime(2026, 10, 7), totalHours: 7));
      expect((await metrics.calculateSleepMetrics(range)).averageHours, 7);
    });
  });

  group('mood', () {
    test('average and distribution', () async {
      for (final (day, level) in [(1, 3), (2, 3), (3, 2), (4, 4)]) {
        await db.upsertMoodEntry(MoodEntry(date: DateTime(2026, 10, day), timestamp: DateTime(2026, 10, day), moodLevel: level, emoji: ''));
      }
      final result = await metrics.calculateMoodMetrics(range);
      expect(result.averageMood, 3);
      expect(result.distribution, {1: 0, 2: 1, 3: 2, 4: 1, 5: 0});
    });
  });

  group('exercise', () {
    test('sums running distance and lifted volume; bodyweight sets count without weight', () async {
      await db.createExerciseEntry(ExerciseEntry(date: DateTime(2026, 10, 2), timestamp: DateTime(2026, 10, 2), type: ExerciseType.run, distance: 5));
      await db.createExerciseEntry(ExerciseEntry(
        date: DateTime(2026, 10, 3),
        timestamp: DateTime(2026, 10, 3),
        type: ExerciseType.weightLifting,
        exerciseName: 'Curl',
        weight: 10,
        reps: 12,
        sets: 3,
      ));
      await db.createExerciseEntry(ExerciseEntry(
        date: DateTime(2026, 10, 3),
        timestamp: DateTime(2026, 10, 3, 1),
        type: ExerciseType.weightLifting,
        exerciseName: 'Situps',
        equipmentType: EquipmentType.bodyweight,
        reps: 60,
        sets: 1,
      ));

      final result = await metrics.calculateExerciseMetrics(range);
      expect(result.totalExercises, 3);
      expect(result.totalRunningDistance, 5);
      expect(result.totalWeightLifted, 360);
    });
  });

  group('activities', () {
    test('ranks tags by frequency', () async {
      final tags = await db.getAllTags();
      final study = tags.firstWhere((t) => t.name == 'Study');
      final work = tags.firstWhere((t) => t.name == 'Work');
      for (final (day, tag) in [(1, study), (2, study), (3, work)]) {
        await db.createActivityEntry(ActivityEntry(date: DateTime(2026, 10, day), timestamp: DateTime(2026, 10, day), tagId: tag.id!));
      }

      final result = await metrics.calculateActivityMetrics(range);
      expect(result.totalActivities, 3);
      expect(result.topActivities.first.tagName, 'Study');
      expect(result.topActivities.first.count, 2);
    });
  });

  group('insights', () {
    // Week of Oct 8-14, compared against Oct 1-7.
    final week = DateRange(start: DateTime(2026, 10, 8), end: DateTime(2026, 10, 14), label: 'Week');

    Future<void> logDays(int fromDay, int count, {required double sleep, required int mood}) async {
      for (var d = fromDay; d < fromDay + count; d++) {
        await db.createSleepEntry(SleepEntry(date: DateTime(2026, 10, d), totalHours: sleep));
        await db.upsertMoodEntry(MoodEntry(date: DateTime(2026, 10, d), timestamp: DateTime(2026, 10, d), moodLevel: mood, emoji: ''));
      }
    }

    test('says nothing about periods with too little data', () async {
      await logDays(8, MetricsService.minDaysForInsight - 1, sleep: 4, mood: 1);
      expect(await metrics.generateInsights(week), isEmpty);
    });

    test('compares with the previous period only when both have enough data', () async {
      await logDays(1, 7, sleep: 6, mood: 3);
      await logDays(8, 7, sleep: 7.5, mood: 4);
      final texts = (await metrics.generateInsights(week)).map((i) => i.text).toList();

      expect(texts, contains('Average sleep was 7.5h over 7 nights, 1.5h more than the previous period'));
      expect(texts, contains('Average mood was 4.0/5 over 7 days, up from 3.0 in the previous period'));
    });

    test('never gives health advice or claims cause and effect', () async {
      await logDays(1, 7, sleep: 9, mood: 5);
      await logDays(8, 7, sleep: 4, mood: 1);
      final texts = (await metrics.generateInsights(DateRange(start: DateTime(2026, 10, 8), end: DateTime(2026, 10, 21), label: 'Two weeks')))
          .map((i) => i.text.toLowerCase())
          .toList();

      expect(texts, isNotEmpty);
      for (final text in texts) {
        for (final phrase in ['try ', 'consider', 'should', 'improve', 'keep up', 'great', 'aligned', 'boost']) {
          expect(text, isNot(contains(phrase)), reason: text);
        }
      }
    });
  });

  group('by day', () {
    test('top activities count days, only activities, and mark everyday habits', () async {
      final games = await db.createTag(Tag(name: 'Gaming', emoji: 'x', category: 'General'));
      final hike = await db.createTag(Tag(name: 'Hiking', emoji: 'x', category: 'General'));
      final takeout = await db.createTag(Tag(name: 'Takeaway', emoji: 'x', category: 'Food', kind: TagKind.foodSource));
      for (var d = 1; d <= 14; d++) {
        final date = DateTime(2026, 3, d);
        await db.createActivityEntry(ActivityEntry(date: date, timestamp: date, tagId: games));
        await db.createActivityEntry(ActivityEntry(date: date, timestamp: date.add(const Duration(hours: 1)), tagId: games));
        await db.createActivityEntry(ActivityEntry(date: date, timestamp: date, tagId: takeout));
        if (d <= 2) await db.createActivityEntry(ActivityEntry(date: date, timestamp: date, tagId: hike));
      }
      final m = await metrics.calculateActivityMetrics(DateRange(start: DateTime(2026, 3, 1), end: DateTime(2026, 3, 31), label: 'March'));
      expect([for (final a in m.topActivities) (a.tagName, a.count, a.percentage, a.everyday)], [
        ('Gaming', 14, 100.0, true),
        ('Hiking', 2, 2 / 14 * 100, false),
      ]);
      expect(m.totalActivities, 16, reason: 'activity days, not every entry');
    });

    test('a few tagged days are too few to call anything everyday', () async {
      final games = await db.createTag(Tag(name: 'Gaming', emoji: 'x', category: 'General'));
      await db.createActivityEntry(ActivityEntry(date: DateTime(2026, 3, 1), timestamp: DateTime(2026, 3, 1), tagId: games));
      final m = await metrics.calculateActivityMetrics(DateRange(start: DateTime(2026, 3, 1), end: DateTime(2026, 3, 7), label: 'Week'));
      expect(m.topActivities.single.everyday, isFalse);
    });

    test('all time compares with nothing before it', () async {
      await db.createExerciseEntry(ExerciseEntry(
          date: DateTime(2026, 3, 1), timestamp: DateTime(2026, 3, 1), type: ExerciseType.weightLifting, exerciseName: 'Sit ups', reps: 20, sets: 1));
      final insights = await metrics.generateInsights(DateRange.allTime());
      expect(insights.map((i) => i.text), contains('1 exercise entry logged'));
      expect(insights.where((i) => i.text.contains('previous period')), isEmpty);
    });
  });
}
