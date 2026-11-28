import 'package:sqflite/sqflite.dart';

/// Schema v24: what was learnt, see SCHEMA.md. Additive and safe to run
/// more than once.
class SchemaV24 {
  SchemaV24._();

  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learning_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        what TEXT NOT NULL,
        so_what TEXT,
        now_what TEXT,
        topic TEXT,
        how TEXT NOT NULL DEFAULT 'work',
        minutes INTEGER,
        rpe INTEGER
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_learning_entries_date ON learning_entries (date)');
  }
}
