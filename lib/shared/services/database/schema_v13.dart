import 'package:sqflite/sqflite.dart';

/// Schema v13: check-ins, journal moments, canonical foods and exercises,
/// health metrics and raw Daylio entries (see SCHEMA.md).
///
/// Purely additive and safe to run more than once, so the same code serves
/// a fresh install and every upgrade path.
class SchemaV13 {
  SchemaV13._();

  static const List<String> foodSourceTags = [
    'Takeout', 'Fast Food', 'Homemade', 'Free Food', 'Restaurant', 'Food Court', 'Delivery', 'Supplement',
  ];

  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS day_checkins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        energy INTEGER,
        stress INTEGER,
        focus INTEGER,
        plant_override TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        time TEXT,
        text TEXT NOT NULL DEFAULT '',
        mood INTEGER,
        source TEXT NOT NULL DEFAULT 'app',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_entry_tags (
        entry_id INTEGER NOT NULL REFERENCES journal_entries (id) ON DELETE CASCADE,
        tag_id INTEGER NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
        PRIMARY KEY (entry_id, tag_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        aliases TEXT NOT NULL DEFAULT '[]',
        kcal REAL,
        kcal_source TEXT,
        last_price REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercise_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        aliases TEXT NOT NULL DEFAULT '[]',
        category TEXT NOT NULL DEFAULT 'strength'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS health_metrics (
        date TEXT NOT NULL,
        metric TEXT NOT NULL,
        value REAL NOT NULL,
        source TEXT NOT NULL,
        PRIMARY KEY (date, metric, source)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS health_workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start TEXT NOT NULL,
        type TEXT NOT NULL,
        duration_min REAL,
        distance_km REAL,
        kcal REAL,
        avg_hr REAL,
        max_hr REAL,
        source TEXT NOT NULL,
        UNIQUE (start, source)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daylio_raw (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        logged_time TEXT NOT NULL,
        mood INTEGER,
        activities TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        UNIQUE (date, logged_time, note)
      )
    ''');

    await _addColumn(db, 'meal_entries', 'food_source', 'TEXT');
    await _addColumn(db, 'meal_entries', 'food_item_id', 'INTEGER REFERENCES food_items (id)');
    await _addColumn(db, 'meal_entries', 'currency', "TEXT NOT NULL DEFAULT 'SGD'");
    await _addColumn(db, 'meal_entries', 'raw_text', 'TEXT');
    await _addColumn(db, 'meal_entries', 'time_known', 'INTEGER NOT NULL DEFAULT 1');
    await _addColumn(db, 'exercise_entries', 'exercise_item_id', 'INTEGER REFERENCES exercise_items (id)');
    await _addColumn(db, 'exercise_entries', 'raw_text', 'TEXT');
    await _addColumn(db, 'activity_entries', 'severity', 'INTEGER');
    if (await _addColumn(db, 'tags', 'kind', "TEXT NOT NULL DEFAULT 'activity'")) {
      await db.execute("UPDATE tags SET kind = 'symptom' WHERE category = 'Health'");
      await db.execute(
        "UPDATE tags SET kind = 'food_source' WHERE name IN (${List.filled(foodSourceTags.length, '?').join(', ')})",
        foodSourceTags,
      );
    }

    for (final table in [
      'sleep_entries', 'nap_entries', 'meal_entries', 'mood_entries', 'exercise_entries',
      'task_entries', 'activity_entries', 'journal_entries', 'daylio_raw',
    ]) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_${table}_date ON $table (date)');
    }
    await db.execute('CREATE INDEX IF NOT EXISTS idx_health_metrics_metric ON health_metrics (metric, date)');
  }

  /// Adds a column unless it exists. Returns whether it was added.
  static Future<bool> _addColumn(DatabaseExecutor db, String table, String column, String definition) async {
    final columns = await db.rawQuery("PRAGMA table_info('$table')");
    if (columns.any((c) => c['name'] == column)) return false;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    return true;
  }
}
