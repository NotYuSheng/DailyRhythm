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
}
