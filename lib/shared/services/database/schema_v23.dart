import 'package:sqflite/sqflite.dart';

/// Schema v23: what a food comes with, and a meal's changes to it, see
/// SCHEMA.md. Additive and safe to run more than once.
class SchemaV23 {
  SchemaV23._();

  static Future<void> apply(DatabaseExecutor db) async {
    Future<void> add(String table, String column) async {
      final columns = await db.rawQuery("PRAGMA table_info('$table')");
      if (!columns.any((c) => c['name'] == column)) await db.execute('ALTER TABLE $table ADD COLUMN $column TEXT');
    }

    await add('food_items', 'comes_with');
    await add('meal_entries', 'changes');
  }
}
