import 'package:sqflite/sqflite.dart';

/// Schema v15: a health score's categories set by the user, on a food
/// (remembered) or one meal, see SCHEMA.md. Additive and safe to run more
/// than once.
class SchemaV15 {
  SchemaV15._();

  static Future<void> apply(DatabaseExecutor db) async {
    for (final table in ['food_items', 'meal_entries']) {
      final columns = [for (final r in await db.rawQuery('PRAGMA table_info($table)')) r['name']];
      if (!columns.contains('health_tags')) await db.execute('ALTER TABLE $table ADD COLUMN health_tags TEXT');
    }
  }
}
