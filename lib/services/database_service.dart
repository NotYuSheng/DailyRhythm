import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sleep_entry.dart';
import '../models/nap_entry.dart';
import '../models/meal_entry.dart';
import '../models/mood_entry.dart';
import '../models/exercise_entry.dart';
import '../models/task_entry.dart';
import '../models/tag.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('liferhythm.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 8,
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
    await db.execute('''
      CREATE TABLE nap_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        startTime TEXT NOT NULL,
        durationHours REAL NOT NULL,
        tags TEXT
      )
    ''');

    // Meal entries table
    await db.execute('''
      CREATE TABLE meal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        name TEXT NOT NULL,
        quantity INTEGER DEFAULT 1,
        price REAL NOT NULL,
        calories INTEGER,
        tags TEXT,
        notes TEXT
      )
    ''');

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

    // Tags table
    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        emoji TEXT NOT NULL,
        category TEXT NOT NULL,
        color TEXT
      )
    ''');

    // Tag categories table
    await db.execute('''
      CREATE TABLE tag_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT
      )
    ''');

    // Create default categories
    await db.insert('tag_categories', {'name': 'General', 'color': null});
    await db.insert('tag_categories', {'name': 'Mood', 'color': null});
    await db.insert('tag_categories', {'name': 'Activity', 'color': null});
    await db.insert('tag_categories', {'name': 'Health', 'color': null});
  }

  // ==================== Sleep Entry CRUD ====================

  Future<int> createSleepEntry(SleepEntry entry) async {
    final db = await database;
    return await db.insert('sleep_entries', entry.toMap());
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
    final dateStr = date.toIso8601String().split('T')[0];
    final maps = await db.query(
      'sleep_entries',
      where: 'date LIKE ?',
      whereArgs: ['$dateStr%'],
      orderBy: 'wakeUpTime DESC',
    );

    return maps.map((map) => SleepEntry.fromMap(map)).toList();
  }

  Future<List<SleepEntry>> getAllSleepEntries() async {
    final db = await database;
    final maps = await db.query('sleep_entries', orderBy: 'date DESC');
    return maps.map((map) => SleepEntry.fromMap(map)).toList();
  }

  Future<int> updateSleepEntry(SleepEntry entry) async {
    final db = await database;
    return await db.update(
      'sleep_entries',
      entry.toMap(),
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
    return await db.insert('nap_entries', entry.toMap());
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
    final dateStr = date.toIso8601String().split('T')[0];
    final maps = await db.query(
      'nap_entries',
      where: 'date LIKE ?',
      whereArgs: ['$dateStr%'],
      orderBy: 'startTime DESC',
    );

    return maps.map((map) => NapEntry.fromMap(map)).toList();
  }

  Future<List<NapEntry>> getAllNapEntries() async {
    final db = await database;
    final maps = await db.query('nap_entries', orderBy: 'date DESC');
    return maps.map((map) => NapEntry.fromMap(map)).toList();
  }

  Future<int> updateNapEntry(NapEntry entry) async {
    final db = await database;
    return await db.update(
      'nap_entries',
      entry.toMap(),
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
    return await db.insert('meal_entries', entry.toMap());
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
    final dateStr = date.toIso8601String().split('T')[0];
    final maps = await db.query(
      'meal_entries',
      where: 'date LIKE ?',
      whereArgs: ['$dateStr%'],
      orderBy: 'time DESC',
    );

    return maps.map((map) => MealEntry.fromMap(map)).toList();
  }

  Future<List<MealEntry>> getAllMealEntries() async {
    final db = await database;
    final maps = await db.query('meal_entries', orderBy: 'date DESC');
    return maps.map((map) => MealEntry.fromMap(map)).toList();
  }

  Future<int> updateMealEntry(MealEntry entry) async {
    final db = await database;
    return await db.update(
      'meal_entries',
      entry.toMap(),
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
    final maps = await db.query('tags', orderBy: 'category, name');
    return maps.map((map) => Tag.fromMap(map)).toList();
  }

  Future<List<Tag>> getTagsByCategory(String category) async {
    final db = await database;
    final maps = await db.query(
      'tags',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'name',
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

  Future<int> deleteTag(int id) async {
    final db = await database;
    return await db.delete(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Mood Entry CRUD ====================

  Future<int> createMoodEntry(MoodEntry entry) async {
    final db = await database;
    return await db.insert('mood_entries', entry.toMap());
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
      entry.toMap(),
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
    final maps = await db.query('tag_categories', orderBy: 'name');
    return maps.map((map) => TagCategory.fromMap(map)).toList();
  }

  Future<int> updateTagCategory(TagCategory category) async {
    final db = await database;
    return await db.update(
      'tag_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteTagCategory(int id) async {
    final db = await database;
    return await db.delete(
      'tag_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Exercise Entry CRUD ====================

  Future<int> createExerciseEntry(ExerciseEntry entry) async {
    final db = await database;
    return await db.insert('exercise_entries', entry.toMap());
  }

  Future<List<ExerciseEntry>> getExerciseEntriesByDate(DateTime date) async {
    final db = await database;
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final maps = await db.query(
      'exercise_entries',
      where: 'date = ?',
      whereArgs: [normalizedDate.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => ExerciseEntry.fromMap(map)).toList();
  }

  Future<int> updateExerciseEntry(ExerciseEntry entry) async {
    final db = await database;
    return await db.update(
      'exercise_entries',
      entry.toMap(),
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
    return await db.insert('task_entries', entry.toMap());
  }

  Future<List<TaskEntry>> getTaskEntriesByDate(DateTime date) async {
    final db = await database;
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final maps = await db.query(
      'task_entries',
      where: 'date = ?',
      whereArgs: [normalizedDate.toIso8601String()],
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

  // ==================== Utility ====================

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
