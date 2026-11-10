import 'package:sqflite/sqflite.dart';

/// Schema v19: a day's meals can be put in the user's own order, see
/// SCHEMA.md. Additive and safe to run more than once.
class SchemaV19 {
  SchemaV19._();

  static Future<void> apply(DatabaseExecutor db) async {
    final columns = await db.rawQuery("PRAGMA table_info('meal_entries')");
    if (!columns.any((c) => c['name'] == 'sort_order')) {
      await db.execute('ALTER TABLE meal_entries ADD COLUMN sort_order INTEGER');
    }
  }
}
