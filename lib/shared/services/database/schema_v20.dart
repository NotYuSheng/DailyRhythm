import 'package:sqflite/sqflite.dart';

/// Schema v20: a food is a meal or a snack, and a side belongs to the meal
/// it came with, see SCHEMA.md. Additive and safe to run more than once.
class SchemaV20 {
  SchemaV20._();

  static Future<void> apply(DatabaseExecutor db) async {
    final columns = {for (final c in await db.rawQuery("PRAGMA table_info('meal_entries')")) c['name']};
    if (!columns.contains('kind')) {
      await db.execute("ALTER TABLE meal_entries ADD COLUMN kind TEXT NOT NULL DEFAULT 'meal'");
    }
    if (!columns.contains('side_of')) {
      await db.execute('ALTER TABLE meal_entries ADD COLUMN side_of INTEGER');
    }
    await db.execute('CREATE INDEX IF NOT EXISTS idx_meal_entries_side_of ON meal_entries(side_of)');
  }
}
