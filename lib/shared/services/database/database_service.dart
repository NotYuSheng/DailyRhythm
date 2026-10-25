import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../utils/date_utils.dart';
import 'schema_v13.dart';
import '../../../features/sleep/data/models/sleep_entry.dart';
import '../../models/nap_entry.dart';
import '../../../features/meals/data/models/meal_entry.dart';
import '../../models/mood_entry.dart';
import '../../../features/exercise/data/models/exercise_entry.dart';
import '../../models/task_entry.dart';
import '../../models/activity_entry.dart';
import '../../../features/tags/data/models/tag.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  static const int schemaVersion = 13;

  /// Overrides the database file location (e.g. `inMemoryDatabasePath`).
  @visibleForTesting
  static String? databasePathOverride;

  DatabaseService._init();

  static const String _fileName = 'dailyrhythm.db';

  /// Location of the database file (used by backup and restore).
  static Future<String> databaseFilePath() async =>
      databasePathOverride ?? join(await getDatabasesPath(), _fileName);

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = await databaseFilePath();

    return await openDatabase(
      path,
      version: schemaVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add mood_entries table for version 2
      await db.execute('''
        CREATE TABLE mood_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          moodLevel INTEGER NOT NULL,
          emoji TEXT NOT NULL,
          notes TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add napHours column to sleep_entries for version 3
      await db.execute('''
        ALTER TABLE sleep_entries ADD COLUMN napHours REAL
      ''');
    }
    if (oldVersion < 4) {
      // Add calories column to meal_entries for version 4
      await db.execute('''
        ALTER TABLE meal_entries ADD COLUMN calories INTEGER
      ''');
    }
    if (oldVersion < 5) {
      // Add quantity column to meal_entries for version 5
      await db.execute('''
        ALTER TABLE meal_entries ADD COLUMN quantity INTEGER DEFAULT 1
      ''');
    }
    if (oldVersion < 6) {
      // Add exercise_entries table for version 6
      await db.execute('''
        CREATE TABLE exercise_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          type TEXT NOT NULL,
          runType TEXT,
          distance REAL,
          duration INTEGER,
          pace INTEGER,
          intervalDistance INTEGER,
          intervalTime INTEGER,
          restTime INTEGER,
          intervalCount INTEGER,
          exerciseName TEXT,
          reps INTEGER,
          weight REAL,
          sets INTEGER,
          notes TEXT
        )
      ''');
    }
    if (oldVersion < 7) {
      // Add task_entries table for version 7
      await db.execute('''
        CREATE TABLE task_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          taskType TEXT NOT NULL,
          notes TEXT
        )
      ''');
    }
    if (oldVersion < 8) {
      // Add equipmentType column to exercise_entries for version 8
      await db.execute('''
        ALTER TABLE exercise_entries ADD COLUMN equipmentType TEXT
      ''');
    }
    if (oldVersion < 9) {
      // Add activity_entries table for version 9
      await db.execute('''
        CREATE TABLE activity_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          tagId INTEGER NOT NULL,
          notes TEXT,
          FOREIGN KEY (tagId) REFERENCES tags (id)
        )
      ''');

      // Add default tags for version 9
      // Using Unicons - storing icon names instead of unicode
      final defaultTags = [
        // Health Issues
        {'name': 'Sore Throat', 'emoji': 'sick', 'category': 'Health'},
        {'name': 'Nausea', 'emoji': 'annoyed', 'category': 'Health'},
        {'name': 'Cough', 'emoji': 'virus_slash', 'category': 'Health'},
        {'name': 'Runny Nose', 'emoji': 'tear', 'category': 'Health'},
        {'name': 'Congestion', 'emoji': 'ban', 'category': 'Health'},
        {'name': 'Neck Pain', 'emoji': 'arrow_up', 'category': 'Health'},
        {'name': 'Rash', 'emoji': 'exclamation_triangle', 'category': 'Health'},
        {'name': 'Back Pain', 'emoji': 'user_arrows', 'category': 'Health'},
        {'name': 'Muscle Ache', 'emoji': 'dumbbell', 'category': 'Health'},
        {'name': 'Headache', 'emoji': 'head_side', 'category': 'Health'},
        {'name': 'Migraine', 'emoji': 'head_side_cough', 'category': 'Health'},
        {'name': 'Gastric Pain', 'emoji': 'hospital', 'category': 'Health'},
        {'name': 'Stomach Ache', 'emoji': 'hospital', 'category': 'Health'},
        {'name': 'Anxiety', 'emoji': 'sad', 'category': 'Health'},
        {'name': 'Drowsiness', 'emoji': 'moon', 'category': 'Health'},
        {'name': 'Constipation', 'emoji': 'ban', 'category': 'Health'},
        {'name': 'Toothache', 'emoji': 'clinic_medical', 'category': 'Health'},
        {'name': 'Fever', 'emoji': 'temperature', 'category': 'Health'},
        {'name': 'Diarrhea', 'emoji': 'hospital', 'category': 'Health'},

        // Common (Work/Study/Entertainment)
        {'name': 'Study', 'emoji': 'book', 'category': 'General'},
        {'name': 'Watch Videos', 'emoji': 'play_circle', 'category': 'General'},
        {'name': 'Class', 'emoji': 'graduation_cap', 'category': 'General'},
        {'name': 'Test', 'emoji': 'file_alt', 'category': 'General'},
        {'name': 'Work', 'emoji': 'briefcase', 'category': 'General'},
        {'name': 'Video Games', 'emoji': 'game_structure', 'category': 'General'},
        {'name': 'Draw', 'emoji': 'brush_alt', 'category': 'General'},
        {'name': 'Intense Exercise', 'emoji': 'dumbbell', 'category': 'General'},
        {'name': 'Social Event', 'emoji': 'glass_martini', 'category': 'General'},
        {'name': 'Family Time', 'emoji': 'home', 'category': 'General'},
        {'name': 'Family Issues', 'emoji': 'exclamation_triangle', 'category': 'General'},
        {'name': 'Change Bedsheets', 'emoji': 'bed', 'category': 'General'},
        {'name': 'Haircut', 'emoji': 'scissors', 'category': 'General'},
      ];

      for (final tag in defaultTags) {
        await db.insert('tags', tag);
      }
    }
    if (oldVersion < 10) {
      // Add sort_order to tags for version 10
      await db.execute('''
        ALTER TABLE tags ADD COLUMN sort_order INTEGER
      ''');
      // Initialize sort_order within each category by name ordering
      final tags = await db.query('tags', orderBy: 'category, name');
      String? currentCat;
      int order = 0;
      for (final t in tags) {
        final cat = t['category'] as String?;
        if (cat != currentCat) {
          currentCat = cat;
          order = 0;
        }
        await db.update('tags', {'sort_order': order}, where: 'id = ?', whereArgs: [t['id']]);
        order++;
      }
    }
    if (oldVersion < 12) {
      // Version 11 shipped without an upgrade step, so databases upgraded from
      // version 10 or earlier never received these tables.
      await db.execute(_napEntriesSql(ifNotExists: true));
      await db.execute(_tagCategoriesSql(ifNotExists: true));
      await _seedTagCategories(db);

      // Price becomes optional (fruit, snacks and free food often have none).
      // SQLite cannot drop NOT NULL in place, so rebuild the table.
      await db.execute(_mealEntriesSql(table: 'meal_entries_new'));
      await db.execute('''
        INSERT INTO meal_entries_new (id, date, time, name, quantity, price, calories, tags, notes)
        SELECT id, date, time, name, quantity, price, calories, tags, notes FROM meal_entries
      ''');
      await db.execute('DROP TABLE meal_entries');
      await db.execute('ALTER TABLE meal_entries_new RENAME TO meal_entries');

      // Some screens stored the save time in `date`, which hid those entries
      // from exact-date lookups. Every `date` is a calendar day.
      for (final table in _datedTables) {
        await db.execute(
          "UPDATE $table SET date = substr(date, 1, 10) || 'T00:00:00.000' "
          "WHERE date NOT LIKE '%T00:00:00.000'",
        );
      }
    }
    if (oldVersion < 13) {
      await SchemaV13.apply(db);
    }
  }

  static const List<String> _datedTables = [
    'sleep_entries',
    'nap_entries',
    'meal_entries',
    'mood_entries',
    'exercise_entries',
    'task_entries',
    'activity_entries',
  ];

  static String _napEntriesSql({bool ifNotExists = false}) => '''
    CREATE TABLE ${ifNotExists ? 'IF NOT EXISTS ' : ''}nap_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      startTime TEXT NOT NULL,
      durationHours REAL NOT NULL,
      tags TEXT
    )
  ''';

  static String _tagCategoriesSql({bool ifNotExists = false}) => '''
    CREATE TABLE ${ifNotExists ? 'IF NOT EXISTS ' : ''}tag_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      color TEXT,
      sort_order INTEGER
    )
  ''';

  static String _mealEntriesSql({String table = 'meal_entries'}) => '''
    CREATE TABLE $table (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      time TEXT NOT NULL,
      name TEXT NOT NULL,
      quantity INTEGER DEFAULT 1,
      price REAL,
      calories INTEGER,
      tags TEXT,
      notes TEXT
    )
  ''';

  /// Ensures the default categories, plus any category already referenced by
  /// a tag, exist in `tag_categories`.
  static Future<void> _seedTagCategories(DatabaseExecutor db) async {
    const defaults = ['General', 'Health', 'Work', 'Hobby', 'Activity'];
    final existing = (await db.query('tag_categories', columns: ['name']))
        .map((row) => row['name'] as String)
        .toSet();
    final used = (await db.rawQuery('SELECT DISTINCT category FROM tags ORDER BY category'))
        .map((row) => row['category'] as String);

    var order = existing.length;
    for (final name in {...defaults, ...used}) {
      if (existing.add(name)) {
        await db.insert('tag_categories', {'name': name, 'color': null, 'sort_order': order++});
      }
    }
  }

  /// Returns [map] with its `date` normalized to the start of that day.
  static Map<String, dynamic> _withDay(Map<String, dynamic> map) {
    final date = map['date'];
    if (date is String) {
      map['date'] = dayOf(DateTime.parse(date)).toIso8601String();
    }
    return map;
  }

  static List<String> _dayRangeArgs(DateTime date) {
    final start = dayOf(date);
    final end = DateTime(start.year, start.month, start.day + 1);
    return [start.toIso8601String(), end.toIso8601String()];
  }

  Future<void> _createDB(Database db, int version) async {
    // Sleep entries table
    await db.execute('''
      CREATE TABLE sleep_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        wakeUpTime TEXT,
        sleepTime TEXT,
        totalHours REAL,
        napHours REAL,
        tags TEXT
      )
    ''');

    // Nap entries table
    await db.execute(_napEntriesSql());

    // Meal entries table
    await db.execute(_mealEntriesSql());

    // Mood entries table
    await db.execute('''
      CREATE TABLE mood_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        moodLevel INTEGER NOT NULL,
        emoji TEXT NOT NULL,
        notes TEXT
      )
    ''');

    // Exercise entries table
    await db.execute('''
      CREATE TABLE exercise_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        type TEXT NOT NULL,
        runType TEXT,
        distance REAL,
        duration INTEGER,
        pace INTEGER,
        intervalDistance INTEGER,
        intervalTime INTEGER,
        restTime INTEGER,
        intervalCount INTEGER,
        exerciseName TEXT,
        equipmentType TEXT,
        reps INTEGER,
        weight REAL,
        sets INTEGER,
        notes TEXT
      )
    ''');

    // Task entries table
    await db.execute('''
      CREATE TABLE task_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        taskType TEXT NOT NULL,
        notes TEXT
      )
    ''');

    // Activity entries table
    await db.execute('''
      CREATE TABLE activity_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        tagId INTEGER NOT NULL,
        notes TEXT,
        FOREIGN KEY (tagId) REFERENCES tags (id)
      )
    ''');

    // Tags table
    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        emoji TEXT NOT NULL,
        category TEXT NOT NULL,
        color TEXT,
        sort_order INTEGER
      )
    ''');

    // Tag categories table
    await db.execute(_tagCategoriesSql());

    // Create default categories with sort order
    await _seedTagCategories(db);

    // Create default tags
    // Using Unicons - storing icon names instead of unicode
    final defaultTags = [
      // Health Issues
      {'name': 'Sore Throat', 'emoji': 'sick', 'category': 'Health'},
      {'name': 'Nausea', 'emoji': 'annoyed', 'category': 'Health'},
      {'name': 'Cough', 'emoji': 'virus_slash', 'category': 'Health'},
      {'name': 'Runny Nose', 'emoji': 'tear', 'category': 'Health'},
      {'name': 'Congestion', 'emoji': 'ban', 'category': 'Health'},
      {'name': 'Neck Pain', 'emoji': 'arrow_up', 'category': 'Health'},
      {'name': 'Rash', 'emoji': 'exclamation_triangle', 'category': 'Health'},
      {'name': 'Back Pain', 'emoji': 'user_arrows', 'category': 'Health'},
      {'name': 'Muscle Ache', 'emoji': 'dumbbell', 'category': 'Health'},
      {'name': 'Headache', 'emoji': 'head_side', 'category': 'Health'},
      {'name': 'Migraine', 'emoji': 'head_side_cough', 'category': 'Health'},
      {'name': 'Gastric Pain', 'emoji': 'hospital', 'category': 'Health'},
      {'name': 'Stomach Ache', 'emoji': 'hospital', 'category': 'Health'},
      {'name': 'Anxiety', 'emoji': 'sad', 'category': 'Health'},
      {'name': 'Drowsiness', 'emoji': 'moon', 'category': 'Health'},
      {'name': 'Constipation', 'emoji': 'ban', 'category': 'Health'},
      {'name': 'Toothache', 'emoji': 'clinic_medical', 'category': 'Health'},
      {'name': 'Fever', 'emoji': 'temperature', 'category': 'Health'},
      {'name': 'Diarrhea', 'emoji': 'hospital', 'category': 'Health'},

      // Work & Study
      {'name': 'Study', 'emoji': 'book', 'category': 'Work'},
      {'name': 'Class', 'emoji': 'graduation_cap', 'category': 'Work'},
      {'name': 'Test', 'emoji': 'file_alt', 'category': 'Work'},
      {'name': 'Work', 'emoji': 'briefcase', 'category': 'Work'},

      // Leisure & Entertainment
      {'name': 'Watch Videos', 'emoji': 'play_circle', 'category': 'Hobby'},
      {'name': 'Video Games', 'emoji': 'game_structure', 'category': 'Hobby'},
      {'name': 'Draw', 'emoji': 'brush_alt', 'category': 'Hobby'},

      // Physical Activity
      {'name': 'Intense Exercise', 'emoji': 'dumbbell', 'category': 'Activity'},

      // Social & Family
      {'name': 'Social Event', 'emoji': 'glass_martini', 'category': 'Activity'},
      {'name': 'Family Time', 'emoji': 'home', 'category': 'Activity'},
      {'name': 'Family Issues', 'emoji': 'exclamation_triangle', 'category': 'Activity'},

      // Household & Personal Care
      {'name': 'Change Bedsheets', 'emoji': 'bed', 'category': 'General'},
      {'name': 'Haircut', 'emoji': 'scissors', 'category': 'General'},
    ];

    for (final tag in defaultTags) {
      await db.insert('tags', tag);
    }

    await SchemaV13.apply(db);
  }

  // ==================== Sleep Entry CRUD ====================

  Future<int> createSleepEntry(SleepEntry entry) async {
    final db = await database;
    return await db.insert('sleep_entries', _withDay(entry.toMap()));
  }

  Future<SleepEntry?> getSleepEntry(int id) async {
    final db = await database;
    final maps = await db.query(
      'sleep_entries',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return SleepEntry.fromMap(maps.first);
    }
    return null;
  }

  Future<List<SleepEntry>> getSleepEntriesByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final maps = await db.query(
      'sleep_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'wakeUpTime DESC',
    );

    return maps.map((map) => SleepEntry.fromMap(map)).toList();
  }

  Future<List<SleepEntry>> getAllSleepEntries() async {
    final db = await database;
    final maps = await db.query('sleep_entries', orderBy: 'date DESC, id DESC');
    return maps.map((map) => SleepEntry.fromMap(map)).toList();
  }

  Future<SleepEntry?> getSleepEntryByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final maps = await db.query(
      'sleep_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'wakeUpTime DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return SleepEntry.fromMap(maps.first);
    }
    return null;
  }

  Future<int> upsertSleepEntry(SleepEntry entry) async {
    final db = await database;
    final existing = await getSleepEntryByDate(entry.date);
    if (existing != null) {
      // Update existing entry, preserving the original ID
      return await updateSleepEntry(entry.copyWith(id: existing.id));
    } else {
      // Create new entry
      return await db.insert('sleep_entries', _withDay(entry.toMap()));
    }
  }

  /// Saves the sleep entry for its day and keeps day totals consistent.
  ///
  /// A day's total runs from the previous day's bedtime to that day's wake
  /// time, so saving day N computes N's total and recomputes N+1's.
  /// Returns the saved total for day N, or null if it cannot be computed.
  Future<double?> saveSleepEntry(SleepEntry entry) async {
    final day = dayOf(entry.date);
    final previous = await getSleepEntryByDate(DateTime(day.year, day.month, day.day - 1));
    final totalHours = previous?.sleepTime != null && entry.wakeUpTime != null
        ? sleepDurationHours(previous!.sleepTime!, entry.wakeUpTime!)
        : null;

    await upsertSleepEntry(SleepEntry(
      id: entry.id,
      date: day,
      wakeUpTime: entry.wakeUpTime,
      sleepTime: entry.sleepTime,
      totalHours: totalHours,
      napHours: entry.napHours,
      tags: entry.tags,
    ));

    final next = await getSleepEntryByDate(DateTime(day.year, day.month, day.day + 1));
    if (next != null && next.wakeUpTime != null && entry.sleepTime != null) {
      await updateSleepEntry(next.copyWith(
        totalHours: sleepDurationHours(entry.sleepTime!, next.wakeUpTime!),
      ));
    }
    return totalHours;
  }

  Future<int> updateSleepEntry(SleepEntry entry) async {
    final db = await database;
    return await db.update(
      'sleep_entries',
      _withDay(entry.toMap()),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteSleepEntry(int id) async {
    final db = await database;
    return await db.delete(
      'sleep_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Nap Entry CRUD ====================

  Future<int> createNapEntry(NapEntry entry) async {
    final db = await database;
    return await db.insert('nap_entries', _withDay(entry.toMap()));
  }

  Future<NapEntry?> getNapEntry(int id) async {
    final db = await database;
    final maps = await db.query(
      'nap_entries',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return NapEntry.fromMap(maps.first);
    }
    return null;
  }

  Future<List<NapEntry>> getNapEntriesByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final maps = await db.query(
      'nap_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'startTime DESC',
    );

    return maps.map((map) => NapEntry.fromMap(map)).toList();
  }

  Future<List<NapEntry>> getAllNapEntries() async {
    final db = await database;
    final maps = await db.query('nap_entries', orderBy: 'date DESC, startTime DESC, id DESC');
    return maps.map((map) => NapEntry.fromMap(map)).toList();
  }

  Future<int> updateNapEntry(NapEntry entry) async {
    final db = await database;
    return await db.update(
      'nap_entries',
      _withDay(entry.toMap()),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteNapEntry(int id) async {
    final db = await database;
    return await db.delete(
      'nap_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Meal Entry CRUD ====================

  Future<int> createMealEntry(MealEntry entry) async {
    final db = await database;
    return await db.insert('meal_entries', _withDay(entry.toMap()));
  }

  Future<MealEntry?> getMealEntry(int id) async {
    final db = await database;
    final maps = await db.query(
      'meal_entries',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return MealEntry.fromMap(maps.first);
    }
    return null;
  }

  Future<List<MealEntry>> getMealEntriesByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final maps = await db.query(
      'meal_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'time DESC',
    );

    return maps.map((map) => MealEntry.fromMap(map)).toList();
  }

  Future<List<MealEntry>> getAllMealEntries() async {
    final db = await database;
    final maps = await db.query('meal_entries', orderBy: 'date DESC, time DESC, id DESC');
    return maps.map((map) => MealEntry.fromMap(map)).toList();
  }

  Future<int> updateMealEntry(MealEntry entry) async {
    final db = await database;
    return await db.update(
      'meal_entries',
      _withDay(entry.toMap()),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteMealEntry(int id) async {
    final db = await database;
    return await db.delete(
      'meal_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Tag CRUD ====================

  Future<int> createTag(Tag tag) async {
    final db = await database;
    return await db.insert('tags', tag.toMap());
  }

  Future<Tag?> getTag(int id) async {
    final db = await database;
    final maps = await db.query(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Tag.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Tag>> getAllTags() async {
    final db = await database;
    final maps = await db.query('tags', orderBy: 'category, sort_order ASC, name ASC');
    return maps.map((map) => Tag.fromMap(map)).toList();
  }

  Future<List<Tag>> getTagsByCategory(String category) async {
    final db = await database;
    final maps = await db.query(
      'tags',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'sort_order ASC, name ASC',
    );
    return maps.map((map) => Tag.fromMap(map)).toList();
  }

  Future<int> updateTag(Tag tag) async {
    final db = await database;
    return await db.update(
      'tags',
      tag.toMap(),
      where: 'id = ?',
      whereArgs: [tag.id],
    );
  }

  Future<void> updateTagOrders(String category, List<int> orderedTagIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < orderedTagIds.length; i++) {
        await txn.update(
          'tags',
          {'sort_order': i, 'category': category},
          where: 'id = ?',
          whereArgs: [orderedTagIds[i]],
        );
      }
    });
  }

  Future<int> getActivityCountForTag(int tagId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM activity_entries WHERE tagId = ?',
      [tagId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> deleteTag(int id) async {
    final db = await database;
    // First delete all activity entries that reference this tag
    await db.delete(
      'activity_entries',
      where: 'tagId = ?',
      whereArgs: [id],
    );
    // Then delete the tag itself
    return await db.delete(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Mood Entry CRUD ====================

  Future<int> createMoodEntry(MoodEntry entry) async {
    final db = await database;
    return await db.insert('mood_entries', _withDay(entry.toMap()));
  }

  Future<int> upsertMoodEntry(MoodEntry entry) async {
    final db = await database;
    final existing = await getMoodEntryByDate(entry.date);
    if (existing != null) {
      // Preserve the original ID when updating
      return await updateMoodEntry(entry.copyWith(id: existing.id));
    } else {
      return await db.insert('mood_entries', _withDay(entry.toMap()));
    }
  }

  Future<MoodEntry?> getMoodEntryByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final maps = await db.query(
      'mood_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return MoodEntry.fromMap(maps.first);
    }
    return null;
  }

  Future<List<MoodEntry>> getMoodEntriesByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.query(
      'mood_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => MoodEntry.fromMap(map)).toList();
  }

  Future<int> updateMoodEntry(MoodEntry entry) async {
    final db = await database;
    return await db.update(
      'mood_entries',
      _withDay(entry.toMap()),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteMoodEntry(int id) async {
    final db = await database;
    return await db.delete(
      'mood_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Tag Category CRUD ====================

  Future<int> createTagCategory(TagCategory category) async {
    final db = await database;
    return await db.insert('tag_categories', category.toMap());
  }

  Future<List<TagCategory>> getAllTagCategories() async {
    final db = await database;
    final maps = await db.query('tag_categories', orderBy: 'sort_order, name');
    return maps.map((map) => TagCategory.fromMap(map)).toList();
  }

  /// Updates a category. Tags reference categories by name, so a rename is
  /// applied to its tags in the same transaction.
  Future<int> updateTagCategory(TagCategory category) async {
    final db = await database;
    return await db.transaction((txn) async {
      final previous = await txn.query(
        'tag_categories',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [category.id],
      );
      final count = await txn.update(
        'tag_categories',
        category.toMap(),
        where: 'id = ?',
        whereArgs: [category.id],
      );
      if (previous.isNotEmpty) {
        final oldName = previous.first['name'] as String;
        if (oldName != category.name) {
          await txn.update(
            'tags',
            {'category': category.name},
            where: 'category = ?',
            whereArgs: [oldName],
          );
        }
      }
      return count;
    });
  }

  Future<int> deleteTagCategory(int id) async {
    final db = await database;
    return await db.delete(
      'tag_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTagCategoryOrders(List<int> orderedCategoryIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < orderedCategoryIds.length; i++) {
        await txn.update(
          'tag_categories',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [orderedCategoryIds[i]],
        );
      }
    });
  }

  // ==================== Exercise Entry CRUD ====================

  Future<int> createExerciseEntry(ExerciseEntry entry) async {
    final db = await database;
    return await db.insert('exercise_entries', _withDay(entry.toMap()));
  }

  Future<List<ExerciseEntry>> getExerciseEntriesByDate(DateTime date) async {
    final db = await database;
    final maps = await db.query(
      'exercise_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: _dayRangeArgs(date),
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => ExerciseEntry.fromMap(map)).toList();
  }

  Future<int> updateExerciseEntry(ExerciseEntry entry) async {
    final db = await database;
    return await db.update(
      'exercise_entries',
      _withDay(entry.toMap()),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteExerciseEntry(int id) async {
    final db = await database;
    return await db.delete(
      'exercise_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Task Entry CRUD ====================

  Future<int> createTaskEntry(TaskEntry entry) async {
    final db = await database;
    return await db.insert('task_entries', _withDay(entry.toMap()));
  }

  Future<List<TaskEntry>> getTaskEntriesByDate(DateTime date) async {
    final db = await database;
    final maps = await db.query(
      'task_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: _dayRangeArgs(date),
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => TaskEntry.fromMap(map)).toList();
  }

  Future<int> deleteTaskEntry(int id) async {
    final db = await database;
    return await db.delete(
      'task_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Activity Entry CRUD ====================

  Future<int> createActivityEntry(ActivityEntry entry) async {
    final db = await database;
    return await db.insert('activity_entries', _withDay(entry.toMap()));
  }

  Future<List<ActivityEntry>> getActivityEntriesByDate(DateTime date) async {
    final db = await database;
    final maps = await db.query(
      'activity_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: _dayRangeArgs(date),
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => ActivityEntry.fromMap(map)).toList();
  }

  Future<int> deleteActivityEntry(int id) async {
    final db = await database;
    return await db.delete(
      'activity_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Date Range Queries (for Metrics) ====================

  Future<List<SleepEntry>> getSleepEntriesInRange(DateTime start, DateTime end) async {
    final db = await database;
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final maps = await db.query(
      'sleep_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'date ASC',
    );
    return maps.map((map) => SleepEntry.fromMap(map)).toList();
  }

  Future<List<MoodEntry>> getMoodEntriesInRange(DateTime start, DateTime end) async {
    final db = await database;
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final maps = await db.query(
      'mood_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'date ASC',
    );
    return maps.map((map) => MoodEntry.fromMap(map)).toList();
  }

  Future<List<ExerciseEntry>> getExerciseEntriesInRange(DateTime start, DateTime end) async {
    final db = await database;
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final maps = await db.query(
      'exercise_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'date ASC',
    );
    return maps.map((map) => ExerciseEntry.fromMap(map)).toList();
  }

  Future<List<ActivityEntry>> getActivityEntriesInRange(DateTime start, DateTime end) async {
    final db = await database;
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final maps = await db.query(
      'activity_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'date ASC',
    );
    return maps.map((map) => ActivityEntry.fromMap(map)).toList();
  }

  Future<List<MealEntry>> getMealEntriesInRange(DateTime start, DateTime end) async {
    final db = await database;
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final maps = await db.query(
      'meal_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'date ASC',
    );
    return maps.map((map) => MealEntry.fromMap(map)).toList();
  }

  // ==================== Full-table Queries (for Export) ====================

  Future<List<MoodEntry>> getAllMoodEntries() async {
    final db = await database;
    final maps = await db.query('mood_entries', orderBy: 'date ASC, id ASC');
    return maps.map((map) => MoodEntry.fromMap(map)).toList();
  }

  Future<List<ExerciseEntry>> getAllExerciseEntries() async {
    final db = await database;
    final maps = await db.query('exercise_entries', orderBy: 'date ASC, timestamp ASC');
    return maps.map((map) => ExerciseEntry.fromMap(map)).toList();
  }

  Future<List<TaskEntry>> getAllTaskEntries() async {
    final db = await database;
    final maps = await db.query('task_entries', orderBy: 'date ASC, timestamp ASC');
    return maps.map((map) => TaskEntry.fromMap(map)).toList();
  }

  Future<List<ActivityEntry>> getAllActivityEntries() async {
    final db = await database;
    final maps = await db.query('activity_entries', orderBy: 'date ASC, timestamp ASC');
    return maps.map((map) => ActivityEntry.fromMap(map)).toList();
  }

  /// Whether [table] has a row whose columns equal [values].
  /// Used by import to skip rows that already exist.
  Future<bool> rowExists(String table, Map<String, Object?> values) async {
    final db = await database;
    final where = values.keys.map((k) => values[k] == null ? '$k IS NULL' : '$k = ?').join(' AND ');
    final args = values.values.where((v) => v != null).toList();
    final result = await db.query(table, columns: ['id'], where: where, whereArgs: args, limit: 1);
    return result.isNotEmpty;
  }

  /// Checks that the file at [path] is a DailyRhythm database this version
  /// of the app can open. Returns a reason it cannot be restored, or null.
  static Future<String?> checkRestorable(String path) async {
    Database? db;
    try {
      db = await openDatabase(path, readOnly: true, singleInstance: false);
      final version = await db.getVersion();
      if (version > schemaVersion) {
        return 'This backup was made by a newer version of DailyRhythm. Update the app first.';
      }
      final tables = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
          .map((row) => row['name'])
          .toSet();
      const required = ['sleep_entries', 'meal_entries', 'mood_entries', 'tags'];
      if (version < 1 || !required.every(tables.contains)) {
        return 'This file is not a DailyRhythm backup.';
      }
      return null;
    } catch (_) {
      return 'The backup file is damaged or not a database.';
    } finally {
      await db?.close();
    }
  }

  // ==================== Utility ====================

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
