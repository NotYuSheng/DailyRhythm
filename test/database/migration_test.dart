import 'dart:io';

import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database.dart';

/// Schema of a database created by app version 10 (or upgraded to 10).
/// It has no `nap_entries` or `tag_categories`, and meal price is NOT NULL.
Future<void> _createVersion10Schema(Database db) async {
  await db.execute('''
    CREATE TABLE sleep_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, wakeUpTime TEXT,
      sleepTime TEXT, totalHours REAL, tags TEXT, napHours REAL)
  ''');
  await db.execute('''
    CREATE TABLE meal_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, time TEXT NOT NULL,
      name TEXT NOT NULL, price REAL NOT NULL, tags TEXT, notes TEXT,
      calories INTEGER, quantity INTEGER DEFAULT 1)
  ''');
  await db.execute('''
    CREATE TABLE mood_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, timestamp TEXT NOT NULL,
      moodLevel INTEGER NOT NULL, emoji TEXT NOT NULL, notes TEXT)
  ''');
  await db.execute('''
    CREATE TABLE exercise_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, timestamp TEXT NOT NULL,
      type TEXT NOT NULL, runType TEXT, distance REAL, duration INTEGER, pace INTEGER,
      intervalDistance INTEGER, intervalTime INTEGER, restTime INTEGER, intervalCount INTEGER,
      exerciseName TEXT, reps INTEGER, weight REAL, sets INTEGER, notes TEXT, equipmentType TEXT)
  ''');
  await db.execute('''
    CREATE TABLE task_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, timestamp TEXT NOT NULL,
      taskType TEXT NOT NULL, notes TEXT)
  ''');
  await db.execute('''
    CREATE TABLE activity_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, timestamp TEXT NOT NULL,
      tagId INTEGER NOT NULL, notes TEXT, FOREIGN KEY (tagId) REFERENCES tags (id))
  ''');
  await db.execute('''
    CREATE TABLE tags (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, emoji TEXT NOT NULL,
      category TEXT NOT NULL, color TEXT, sort_order INTEGER)
  ''');

  await db.insert('tags', {'name': 'Push Day', 'emoji': 'dumbbell', 'category': 'Fitness', 'sort_order': 0});
  await db.insert('tags', {'name': 'Headache', 'emoji': 'head', 'category': 'Health', 'sort_order': 1});
  await db.insert('tags', {'name': 'Takeout', 'emoji': 'bag', 'category': 'Food', 'sort_order': 2});
  await db.insert('meal_entries', {
    'date': '2024-03-01T00:00:00.000',
    'time': '2024-03-01T12:30:00.000',
    'name': 'Wanton noodles',
    'price': 3.5,
    'quantity': 1,
  });
  // Saved by the old exercise screen with the time of day in `date`.
  await db.insert('exercise_entries', {
    'date': '2024-03-01T18:42:10.123',
    'timestamp': '2024-03-01T18:42:10.123',
    'type': 'ExerciseType.weightLifting',
    'exerciseName': 'Situps',
    'reps': 60,
    'sets': 1,
  });
}

Future<String> _prepareOldDatabase(Directory dir, int version) async {
  final path = '${dir.path}/v$version.db';
  sqfliteFfiInit();
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    path,
    options: OpenDatabaseOptions(version: version, onCreate: (db, _) => _createVersion10Schema(db)),
  );
  await db.close();
  return path;
}

Future<Map<String, List<String>>> _columns(Database db) async {
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  return {
    for (final t in tables)
      t['name'] as String: [
        for (final c in await db.rawQuery("PRAGMA table_info('${t['name']}')")) '${c['name']}:${c['notnull']}',
      ]..sort(),
  };
}

/// A version 11 database that did get its tables (a fresh v11 install):
/// one default category deleted on purpose, and a day with two sleep rows
/// from before dates were normalized.
Future<String> _prepareWorkingVersion11(Directory dir) async {
  final path = '${dir.path}/v11_working.db';
  sqfliteFfiInit();
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 11,
      onCreate: (db, _) async {
        await _createVersion10Schema(db);
        await db.execute('CREATE TABLE tag_categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, color TEXT, sort_order INTEGER)');
        for (final name in ['General', 'Health', 'Hobby', 'Activity', 'Fitness', 'Food']) {
          await db.insert('tag_categories', {'name': name});
        }
        await db.insert('sleep_entries', {'date': '2024-03-04T00:00:00.000', 'sleepTime': '2024-03-04T23:00:00.000'});
        await db.insert('sleep_entries', {'date': '2024-03-05T00:00:00.000', 'wakeUpTime': '2024-03-05T07:00:00.000', 'tags': 'sick', 'totalHours': 3});
        await db.insert('sleep_entries', {'date': '2024-03-05T22:10:00.000', 'sleepTime': '2024-03-05T22:10:00.000'});
        await db.insert('sleep_entries', {'date': '2024-03-06T00:00:00.000', 'wakeUpTime': '2024-03-06T06:10:00.000'});
        await db.insert('mood_entries', {'date': '2024-03-05T00:00:00.000', 'timestamp': '2024-03-05T09:00:00.000', 'moodLevel': 2, 'emoji': 'x', 'notes': 'Rough morning'});
        await db.insert('mood_entries', {'date': '2024-03-05T21:00:00.000', 'timestamp': '2024-03-05T21:00:00.000', 'moodLevel': 4, 'emoji': 'x'});
      },
    ),
  );
  await db.close();
  return path;
}

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('dailyrhythm_migration'));
  tearDown(() async {
    await closeTestDatabase();
    await dir.delete(recursive: true);
  });

  // 11 is the broken state: the app shipped v11 with no upgrade step, so
  // devices that upgraded from 10 report version 11 but lack the new tables.
  for (final version in [10, 11]) {
    group('upgrade from version $version', () {
      late DatabaseService service;

      setUp(() async => service = await openTestDatabase(path: await _prepareOldDatabase(dir, version)));

      test('reaches the current schema version', () async {
        final db = await service.database;
        expect(await db.getVersion(), DatabaseService.schemaVersion);
      });

      test('creates the missing tag_categories and nap_entries tables', () async {
        final categories = (await service.getAllTagCategories()).map((c) => c.name);
        expect(categories, containsAll(['General', 'Health', 'Work', 'Hobby', 'Activity']));
        // Categories already used by tags are kept, so those tags stay visible.
        expect(categories, contains('Fitness'));
        expect(await service.getAllNapEntries(), isEmpty);
      });

      test('keeps existing meals and makes price optional', () async {
        final meals = await service.getAllMealEntries();
        expect(meals.single.name, 'Wanton noodles');
        expect(meals.single.price, 3.5);

        final db = await service.database;
        await db.insert('meal_entries', {
          'date': '2024-03-02T00:00:00.000',
          'time': '2024-03-02T10:00:00.000',
          'name': 'Apple',
          'price': null,
        });
      });

      test('normalizes dates so old entries show up on their day', () async {
        final entries = await service.getExerciseEntriesByDate(DateTime(2024, 3, 1));
        expect(entries.single.exerciseName, 'Situps');
        expect(entries.single.date, DateTime(2024, 3, 1));
      });

      test('sorts existing tags into activities, symptoms and food sources', () async {
        final kinds = {for (final t in await service.getAllTags()) t.name: t.kind};
        expect(kinds, {'Push Day': 'activity', 'Headache': 'symptom', 'Takeout': 'food_source'});
      });

      test('adds the v13 tables empty', () async {
        final db = await service.database;
        for (final table in [
          'day_checkins', 'journal_entries', 'journal_entry_tags', 'food_items',
          'exercise_items', 'health_metrics', 'health_workouts', 'daylio_raw',
        ]) {
          expect(await db.query(table), isEmpty, reason: table);
        }
        expect((await service.getAllMealEntries()).single.currency, 'SGD');
      });

      test('matches the schema of a fresh install', () async {
        final upgraded = await _columns(await service.database);
        await closeTestDatabase();
        final fresh = await _columns(await (await openTestDatabase()).database);
        expect(upgraded, fresh);
      });
    });
  }

  group('upgrade from a working version 11', () {
    late DatabaseService service;

    setUp(() async => service = await openTestDatabase(path: await _prepareWorkingVersion11(dir)));

    test('doesn\'t bring back default categories that were deleted', () async {
      final categories = (await service.getAllTagCategories()).map((c) => c.name);
      expect(categories, isNot(contains('Work')));
      expect(categories, contains('Hobby'));
    });

    test('merges days that had two sleep or mood rows', () async {
      final sleep = await service.getSleepEntryByDate(DateTime(2024, 3, 5));
      expect(sleep!.wakeUpTime, DateTime(2024, 3, 5, 7));
      expect(sleep.sleepTime, DateTime(2024, 3, 5, 22, 10));
      expect(sleep.tags, ['sick']);
      expect(sleep.totalHours, 8, reason: '23:00 the night before to 07:00');
      expect((await service.getSleepEntryByDate(DateTime(2024, 3, 6)))!.totalHours, 8, reason: '22:10 to 06:10');
      final db = await service.database;
      expect(await db.query('sleep_entries', where: 'date LIKE ?', whereArgs: ['2024-03-05%']), hasLength(1));
      final moods = await db.query('mood_entries');
      expect([for (final m in moods) (m['moodLevel'], m['notes'])], [(4, 'Rough morning')]);
    });
  });
}
