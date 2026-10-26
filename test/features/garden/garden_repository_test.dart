import 'package:daily_rhythm/features/exercise/data/models/exercise_entry.dart';
import 'package:daily_rhythm/features/garden/data/garden_repository.dart';
import 'package:daily_rhythm/features/garden/domain/plant.dart';
import 'package:daily_rhythm/features/health/data/models/health_metric.dart';
import 'package:daily_rhythm/features/journal/data/models/journal_entry.dart';
import 'package:daily_rhythm/features/sleep/data/models/sleep_entry.dart';
import 'package:daily_rhythm/shared/models/activity_entry.dart';
import 'package:daily_rhythm/shared/models/day_checkin.dart';
import 'package:daily_rhythm/shared/models/mood_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
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
    expect(g.sleepHours, 8.5);
    expect(g.plant.sleep, 4);
    expect(g.moveCount, 2, reason: 'distinct exercises');
    expect(g.plant.flower, isTrue);
  });

  test('watch data fills sleep and movement; a pick overrides the plant', () async {
    await HealthRepository(db).saveMetrics([
      HealthMetric(date: day, metric: 'sleep_minutes', value: 330, source: HealthSource.garminExport),
      HealthMetric(date: day, metric: 'steps', value: 13000, source: HealthSource.garminExport),
    ]);
    await HealthRepository(db).saveWorkouts([
      HealthWorkout(start: DateTime(2026, 10, 20, 18), type: 'running', source: HealthSource.garminExport),
    ]);
    await CheckinRepository(db).save(DayCheckin(date: day, plantOverride: 'tulip'));

    final g = (await GardenRepository(db).daysInRange(day, day)).single;
    expect(g.sleepHours, 5.5);
    expect(g.moveCount, 3);
    expect((g.plant.species, g.chosen, g.plant.logged), (PlantSpecies.tulip, true, true));
  });

  test('tags logged on most of the previous weeks count as routine', () async {
    final work = await tagId('Work');
    for (var i = 1; i <= 20; i++) {
      final d = day.subtract(Duration(days: i));
      await db.createActivityEntry(ActivityEntry(date: d, timestamp: d, tagId: work));
    }
    await db.createActivityEntry(ActivityEntry(date: day, timestamp: day, tagId: work));
    await db.createActivityEntry(ActivityEntry(date: day, timestamp: day, tagId: await tagId('Family Time')));

    final g = (await GardenRepository(db).daysInRange(day, day)).single;
    expect(g.plant.species, PlantSpecies.tulip);
  });

  test('returns every day in the range, empty ones included', () async {
    await db.upsertMoodEntry(MoodEntry(date: DateTime(2026, 10, 2), timestamp: DateTime(2026, 10, 2), moodLevel: 4, emoji: ''));
    final days = await GardenRepository(db).daysInRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
    expect(days, hasLength(31));
    expect(days.where((d) => d.plant.logged).map((d) => d.date), [DateTime(2026, 10, 2)]);
  });
}
