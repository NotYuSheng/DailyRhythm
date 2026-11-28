import 'package:sqflite/sqflite.dart';

/// Schema v22: a food's brand or chain, see SCHEMA.md. Additive and safe to
/// run more than once.
class SchemaV22 {
  SchemaV22._();

  static Future<void> apply(DatabaseExecutor db) async {
    final columns = await db.rawQuery("PRAGMA table_info('food_items')");
    if (!columns.any((c) => c['name'] == 'brand')) {
      await db.execute('ALTER TABLE food_items ADD COLUMN brand TEXT');
    }
  }
}
