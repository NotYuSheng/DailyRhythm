import 'package:daily_rhythm/features/health/data/models/health_metric.dart';
import 'package:daily_rhythm/features/metrics/data/models/metric_data.dart';
import 'package:daily_rhythm/features/metrics/data/services/day_ratings_service.dart';
import 'package:daily_rhythm/features/tags/data/models/tag.dart';
import 'package:daily_rhythm/shared/models/activity_entry.dart';
import 'package:daily_rhythm/shared/models/day_checkin.dart';
import 'package:daily_rhythm/shared/models/mood_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/repositories/checkin_repository.dart';
import 'package:daily_rhythm/shared/services/database/repositories/health_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

RatedDay day(int d, Map<Rating, int> ratings, [Set<String> tags = const {}]) => RatedDay(DateTime(2026, 3, d), ratings, tags);

void main() {
  group('pure aggregations', () {
    test('summaries count each value and average them', () {
      final days = [
        day(1, {Rating.energy: 1}),
        day(2, {Rating.energy: 1, Rating.mood: 4}),
        day(3, {Rating.energy: -1}),
      ];
      final s = DayRatingsService.summarize(Rating.energy, days);
      expect(s.counts, {-2: 0, -1: 1, 0: 0, 1: 2, 2: 0});
      expect(s.days, 3);
      expect(s.average, closeTo(1 / 3, 1e-9));
      expect(Rating.energy.wordNear(s.average!), 'Usual');
      expect(DayRatingsService.summarize(Rating.mood, days).days, 1);
    });

    test('the previous period needs the minimum days to compare', () {
      final now = [day(10, {Rating.focus: 1})];
      final few = [for (var d = 1; d <= 4; d++) day(d, {Rating.focus: 0})];
      expect(DayRatingsService.summarize(Rating.focus, now, few).previousAverage, isNull);
      final enough = [...few, day(5, {Rating.focus: -1})];
      expect(DayRatingsService.summarize(Rating.focus, now, enough).previousAverage, closeTo(-0.2, 1e-9));
    });

    test('tag comparisons need minimum days on both sides and a real difference', () {
      final days = [
        for (var d = 1; d <= 5; d++) day(d, {Rating.energy: 1, Rating.mood: 3}, {'Gym'}),
        for (var d = 6; d <= 10; d++) day(d, {Rating.energy: 0, Rating.mood: 3}),
        for (var d = 11; d <= 14; d++) day(d, {Rating.energy: -1, Rating.mood: 3}, {'Rain'}),
      ];
      final comparisons = DayRatingsService.compareTags(days);
      expect(comparisons.map((c) => (c.tag, c.rating)), [('Gym', Rating.energy)],
          reason: 'Rain has only 4 days; mood never differs');
      expect(comparisons.single.text, 'Energy averaged +1.0 on 5 days with Gym and -0.4 on 9 other days');
    });

    test('small differences are left out', () {
      final days = [
        for (var d = 1; d <= 5; d++) day(d, {Rating.stress: d == 1 ? 1 : 0}, {'Work'}),
        for (var d = 6; d <= 10; d++) day(d, {Rating.stress: 0}),
      ];
      expect(DayRatingsService.compareTags(days), isEmpty);
    });
  });

  group('report', () {
    late DatabaseService db;
    setUp(() async => db = await openTestDatabase());
    tearDown(closeTestDatabase);

    test('reads moods, check-ins, tags and watch averages for the range', () async {
      final march = DateRange(start: DateTime(2026, 3, 1), end: DateTime(2026, 3, 31), label: 'March');
      final gym = await db.createTag(Tag(name: 'Gym', emoji: 'x', category: 'General'));
      for (var d = 1; d <= 12; d++) {
        final date = DateTime(2026, 3, d);
        await db.upsertMoodEntry(MoodEntry(date: date, timestamp: date, moodLevel: 3, emoji: ''));
        await CheckinRepository(db).save(DayCheckin(date: date, energy: d <= 6 ? 2 : 0));
        if (d <= 6) await db.createActivityEntry(ActivityEntry(date: date, timestamp: date, tagId: gym));
      }
      await HealthRepository(db).saveMetrics([
        for (var d = 1; d <= 4; d++)
          HealthMetric(date: DateTime(2026, 3, d), metric: 'sleep_minutes', value: 450, source: HealthSource.garminExport),
      ]);

      final report = await DayRatingsService(db).reportFor(march);
      final energy = report.summaries.firstWhere((s) => s.rating == Rating.energy);
      expect((energy.days, energy.average), (12, 1.0));
      expect(report.comparisons.single.tag, 'Gym');
      expect(report.watch.single.metric, WatchMetric.sleep);
      expect(report.watch.single.average, 7.5);
    });
  });
}
