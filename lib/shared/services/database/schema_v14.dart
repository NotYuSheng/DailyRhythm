import 'package:sqflite/sqflite.dart';

/// Schema v14: spending that isn't a meal (events and gifts), see SCHEMA.md.
/// Additive and safe to run more than once.
class SchemaV14 {
  SchemaV14._();

  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS spending_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        time TEXT,
        label TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'SGD',
        category TEXT NOT NULL DEFAULT 'event',
        notes TEXT,
        raw_text TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spending_entries_date ON spending_entries (date)');
  }
}
