import 'package:daily_rhythm/features/exercise/data/models/exercise_entry.dart';
import 'package:daily_rhythm/features/metrics/data/models/metric_data.dart';
import 'package:daily_rhythm/features/metrics/data/services/metrics_service.dart';
import 'package:daily_rhythm/features/tags/data/models/tag.dart';
import 'package:daily_rhythm/shared/models/activity_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  setUp(() async => db = await openTestDatabase());
  tearDown(closeTestDatabase);

  test('top activities count days, only activities, and mark everyday habits', () async {
    final games = await db.createTag(Tag(name: 'Gaming', emoji: 'x', category: 'General'));
    final hike = await db.createTag(Tag(name: 'Hiking', emoji: 'x', category: 'General'));
    final takeout = await db.createTag(Tag(name: 'Takeaway', emoji: 'x', category: 'Food', kind: TagKind.foodSource));
    for (var d = 1; d <= 10; d++) {
      final date = DateTime(2026, 3, d);
      await db.createActivityEntry(ActivityEntry(date: date, timestamp: date, tagId: games));
      await db.createActivityEntry(ActivityEntry(date: date, timestamp: date.add(const Duration(hours: 1)), tagId: games));
      await db.createActivityEntry(ActivityEntry(date: date, timestamp: date, tagId: takeout));
      if (d <= 2) await db.createActivityEntry(ActivityEntry(date: date, timestamp: date, tagId: hike));
    }
    final m = await MetricsService(db).calculateActivityMetrics(DateRange(start: DateTime(2026, 3, 1), end: DateTime(2026, 3, 31), label: 'March'));
    expect([for (final a in m.topActivities) (a.tagName, a.count, a.percentage, a.everyday)], [
      ('Gaming', 10, 100.0, true),
      ('Hiking', 2, 20.0, false),
    ]);
  });

  test('all time compares with nothing before it', () async {
    await db.createExerciseEntry(ExerciseEntry(
        date: DateTime(2026, 3, 1), timestamp: DateTime(2026, 3, 1), type: ExerciseType.weightLifting, exerciseName: 'Sit ups', reps: 20, sets: 1));
    final insights = await MetricsService(db).generateInsights(DateRange.allTime());
    expect(insights.map((i) => i.text), contains('1 exercise entry logged'));
    expect(insights.where((i) => i.text.contains('previous period')), isEmpty);
  });
}
