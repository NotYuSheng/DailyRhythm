import 'dart:io';

import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/shared/services/backup/backup_service.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database.dart';

void main() {
  late Directory dir;
  late DatabaseService db;
  late String livePath;

  Future<void> addMeal(String name) => db.createMealEntry(
        MealEntry(date: DateTime(2026, 10, 20), time: DateTime(2026, 10, 20, 12), name: name),
      );

  Future<List<String>> mealNames() async => [for (final m in await db.getAllMealEntries()) m.name];

  /// Makes a backup file containing one meal by running the app's own schema.
  Future<File> makeBackup(String meal) async {
    final path = '${dir.path}/backup_$meal.db';
    db = await openTestDatabase(path: path);
    await addMeal(meal);
    db = await openTestDatabase(path: livePath);
    return File(path);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dailyrhythm_restore');
    livePath = '${dir.path}/dailyrhythm.db';
    db = await openTestDatabase(path: livePath);
    await addMeal('Current');
  });
  tearDown(() async {
    await closeTestDatabase();
    await dir.delete(recursive: true);
  });

  test('replaces the data and keeps the previous database as a fallback', () async {
    final backup = await makeBackup('From backup');

    final result = await BackupService.instance.restoreFromFile(backup);

    expect(result.success, isTrue, reason: result.message);
    expect(await mealNames(), ['From backup']);
    expect(File('${dir.path}/dailyrhythm_backup_before_restore.db').existsSync(), isTrue);
  });

  test('rejects a file that is not a database and leaves data untouched', () async {
    final junk = File('${dir.path}/junk.db')..writeAsStringSync('not a database');

    final result = await BackupService.instance.restoreFromFile(junk);

    expect(result.success, isFalse);
    expect(await mealNames(), ['Current']);
  });

  test('rejects a backup from a newer app version', () async {
    final backup = await makeBackup('Future');
    final raw = await databaseFactoryFfiNoIsolate.openDatabase(backup.path);
    await raw.setVersion(DatabaseService.schemaVersion + 1);
    await raw.close();

    final result = await BackupService.instance.restoreFromFile(backup);

    expect(result.success, isFalse);
    expect(result.message, contains('newer version'));
    expect(await mealNames(), ['Current']);
  });

  test('upgrades a backup made by an older app version', () async {
    final backup = await makeBackup('Old');
    // Pretend the backup predates v12 so the upgrade path runs on restore.
    final raw = await databaseFactoryFfiNoIsolate.openDatabase(backup.path);
    await raw.execute('DROP TABLE nap_entries');
    await raw.setVersion(11);
    await raw.close();

    final result = await BackupService.instance.restoreFromFile(backup);

    expect(result.success, isTrue, reason: result.message);
    expect(await mealNames(), ['Old']);
    expect(await (await db.database).getVersion(), DatabaseService.schemaVersion);
    expect(await db.getAllNapEntries(), isEmpty);
  });

  test('accepts a version 1 backup, which had no mood table yet', () async {
    final path = '${dir.path}/v1.db';
    final raw = await databaseFactoryFfiNoIsolate.openDatabase(path);
    for (final table in ['sleep_entries', 'meal_entries', 'tags']) {
      await raw.execute('CREATE TABLE $table (id INTEGER PRIMARY KEY)');
    }
    await raw.setVersion(1);
    await raw.close();

    expect(await DatabaseService.checkRestorable(path), isNull);
  });

  test('a backup that fails to open, with no data to go back to, leaves an empty working database', () async {
    final path = '${dir.path}/broken.db';
    final raw = await databaseFactoryFfiNoIsolate.openDatabase(path);
    // Passes the check, but the v12 upgrade can't rebuild this meal table.
    await raw.execute('CREATE TABLE sleep_entries (id INTEGER PRIMARY KEY, date TEXT)');
    await raw.execute('CREATE TABLE meal_entries (id INTEGER PRIMARY KEY)');
    await raw.execute('CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT, category TEXT)');
    await raw.setVersion(11);
    await raw.close();
    await closeTestDatabase();
    await File(livePath).delete();
    db = await openTestDatabase(path: livePath);
    await db.close();
    await File(livePath).delete();

    final result = await BackupService.instance.restoreFromFile(File(path));

    expect(result.success, isFalse);
    expect(await mealNames(), isEmpty);
  });

  test('a snapshot copies the data without closing the database', () async {
    final copy = '${dir.path}/snapshot.db';
    await db.snapshotTo(copy);
    await addMeal('After');

    final snapshot = await databaseFactoryFfiNoIsolate.openDatabase(copy);
    expect([for (final r in await snapshot.query('meal_entries')) r['name']], ['Current']);
    await snapshot.close();
    expect(await mealNames(), unorderedEquals(['Current', 'After']));
  });
}
