import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'package:daily_rhythm/features/exercise/data/models/exercise_entry.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/sleep/data/models/sleep_entry.dart';
import 'package:daily_rhythm/features/tags/data/models/tag.dart';
import 'package:daily_rhythm/shared/models/activity_entry.dart';
import 'package:daily_rhythm/shared/models/mood_entry.dart';
import 'package:daily_rhythm/shared/models/nap_entry.dart';
import 'package:daily_rhythm/shared/models/task_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/export/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

/// Five-year-old data must survive: the old export only covered 365 days.
final _old = DateTime(2021, 9, 10);

Future<void> _seed(DatabaseService db) async {
  await db.saveSleepEntry(SleepEntry(date: _old, wakeUpTime: DateTime(2021, 9, 10, 7), sleepTime: DateTime(2021, 9, 10, 23, 45)));
  await db.createNapEntry(NapEntry(date: _old, startTime: DateTime(2021, 9, 10, 14), durationHours: 0.5));
  await db.createMealEntry(MealEntry(date: _old, time: DateTime(2021, 9, 10, 12), name: 'Yong Tau Foo', price: 5.2, tags: ['Food Court']));
  await db.createMealEntry(MealEntry(date: _old, time: DateTime(2021, 9, 10, 16), name: 'Banana, "ripe"', notes: 'line one\nline two'));
  await db.upsertMoodEntry(MoodEntry(date: _old, timestamp: DateTime(2021, 9, 10, 23, 55), moodLevel: 3, emoji: ''));
  await db.createExerciseEntry(ExerciseEntry(
    date: _old,
    timestamp: DateTime(2021, 9, 10, 20),
    type: ExerciseType.run,
    runType: RunType.flat,
    distance: 5,
    duration: const Duration(minutes: 30, seconds: 15),
    pace: const Duration(minutes: 6, seconds: 3),
  ));
  await db.createExerciseEntry(ExerciseEntry(
    date: _old,
    timestamp: DateTime(2021, 9, 10, 21),
    type: ExerciseType.weightLifting,
    exerciseName: 'Situps',
    equipmentType: EquipmentType.bodyweight,
    reps: 60,
    sets: 1,
  ));
  await db.createTaskEntry(TaskEntry(date: _old, timestamp: DateTime(2021, 9, 10, 10), taskType: TaskType.haircut));
  final tagId = await db.createTag(Tag(name: 'Gaming', emoji: 'game_structure', category: 'Hobby'));
  await db.createActivityEntry(ActivityEntry(date: _old, timestamp: DateTime(2021, 9, 10, 22), tagId: tagId));
}

Future<Map<String, Object>> _snapshot(DatabaseService db) async {
  final tags = {for (final t in await db.getAllTags()) t.id: t.name};
  return {
    'sleep': [for (final e in await db.getAllSleepEntries()) [e.date, e.wakeUpTime, e.sleepTime, e.totalHours, e.napHours]],
    'naps': [for (final e in await db.getAllNapEntries()) [e.date, e.startTime, e.durationHours]],
    'meals': [for (final e in await db.getAllMealEntries()) [e.date, e.time, e.name, e.quantity, e.price, e.tags, e.notes]],
    'mood': [for (final e in await db.getAllMoodEntries()) [e.date, e.moodLevel]],
    'exercise': [
      for (final e in await db.getAllExerciseEntries())
        [e.date, e.timestamp, e.type, e.runType, e.distance, e.duration, e.pace, e.exerciseName, e.equipmentType, e.reps, e.weight, e.sets],
    ],
    'tasks': [for (final e in await db.getAllTaskEntries()) [e.date, e.taskType]],
    // Compare by tag name: IDs differ on a fresh install.
    'activities': [for (final e in await db.getAllActivityEntries()) [e.date, tags[e.tagId]]],
    'tags': (await db.getAllTags()).map((t) => '${t.category}/${t.name}').toList()..sort(),
  };
}

void main() {
  late Directory dir;
  late DatabaseService db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dailyrhythm_export');
    db = await openTestDatabase();
  });
  tearDown(() async {
    await closeTestDatabase();
    await dir.delete(recursive: true);
  });

  test('round-trips every table, including entries older than a year', () async {
    await _seed(db);
    final before = await _snapshot(db);

    final exported = await ExportService.instance.exportToDirectory(dir);
    expect(File('${dir.path}/nap_entries.csv').existsSync(), isTrue);
    expect(exported.fileCount, 9); // one file per table

    // Simulate a new phone: empty database with fresh tag IDs.
    await closeTestDatabase();
    db = await openTestDatabase();
    final result = await ExportService.instance.importFromDirectory(dir.path);

    expect(result.invalid, 0);
    expect(await _snapshot(db), before);
  });

  test('round-trips through the zip used by the save dialog', () async {
    await _seed(db);
    final before = await _snapshot(db);
    final (:bytes, :summary) = await ExportService.instance.buildExportZip();
    expect(summary.fileCount, 9);

    await closeTestDatabase();
    db = await openTestDatabase();
    final result = await ExportService.instance.importFromZipBytes(bytes);

    expect(result.invalid, 0);
    expect(await _snapshot(db), before);
  });

  test('imports a zip of an old export folder with nested paths', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.bytes(
        'DailyRhythm_Export_2025-01-05/meal_entries.csv',
        utf8.encode('ID,Date,Time,Name,Quantity,Price,Calories,Tags,Notes\r\n'
            '1,2025-01-05T00:00:00.000,2025-01-05T13:00:00.000,Noodles,1,4.5,,,'),
      ));
    final result = await ExportService.instance.importFromZipBytes(ZipEncoder().encodeBytes(archive));
    expect(result.imported, 1);
    expect((await db.getAllMealEntries()).single.name, 'Noodles');
  });

  test('importing the same export twice adds nothing the second time', () async {
    await _seed(db);
    await ExportService.instance.exportToDirectory(dir);
    await closeTestDatabase();
    db = await openTestDatabase();

    await ExportService.instance.importFromDirectory(dir.path);
    final once = await _snapshot(db);
    final second = await ExportService.instance.importFromDirectory(dir.path);

    expect(second.imported, 0);
    expect(second.duplicates, greaterThan(0));
    expect(await _snapshot(db), once);
  });

  test('reads exercise and activity files written by the previous export format', () async {
    final tags = await db.getAllTags();
    final studyId = tags.firstWhere((t) => t.name == 'Study').id;
    await File('${dir.path}/tags.csv').writeAsString(
      'ID,Name,Emoji,Category,Color,Sort Order\r\n$studyId,Study,book,Work,,0',
    );
    await File('${dir.path}/exercise_entries.csv').writeAsString(
      'ID,Date,Timestamp,Type,Run Type,Distance,Duration,Pace,Interval Distance,Interval Time,'
      'Rest Time,Interval Count,Exercise Name,Equipment Type,Reps,Weight,Sets,Notes\r\n'
      '1,2025-01-05T00:00:00.000,2025-01-05T19:00:00.000,ExerciseType.run,RunType.flat,5.0,'
      '0:30:00.000000,0:06:00.000000,,,,,,,,,,',
    );
    await File('${dir.path}/activity_entries.csv').writeAsString(
      'ID,Date,Timestamp,Tag ID,Notes\r\n1,2025-01-05T00:00:00.000,2025-01-05T09:00:00.000,$studyId,',
    );

    final result = await ExportService.instance.importFromDirectory(dir.path);

    expect(result.invalid, 0);
    final run = (await db.getAllExerciseEntries()).single;
    expect(run.duration, const Duration(minutes: 30));
    expect(run.runType, RunType.flat);
    expect((await db.getAllActivityEntries()).single.tagId, studyId);
  });

  test('counts unreadable rows instead of dropping them silently', () async {
    await File('${dir.path}/meal_entries.csv').writeAsString(
      'ID,Date,Time,Name,Quantity,Price,Calories,Tags,Notes\r\n'
      '1,not-a-date,2025-01-05T12:00:00.000,Rice,1,3.0,,,\r\n'
      '2,2025-01-05T00:00:00.000,2025-01-05T13:00:00.000,Noodles,1,4.5,,,',
    );
    final result = await ExportService.instance.importFromDirectory(dir.path);
    expect(result.imported, 1);
    expect(result.invalid, 1);
  });

  test('reports when a folder has no export files', () async {
    final result = await ExportService.instance.importFromDirectory(dir.path);
    expect(result.foundFiles, isFalse);
  });
}
