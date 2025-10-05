import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sleep_entry.dart';
import '../models/nap_entry.dart';
import '../models/meal_entry.dart';
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
      version: 1,
      onCreate: _createDB,
    );
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
        price REAL NOT NULL,
        tags TEXT,
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

  // ==================== Utility ====================

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
