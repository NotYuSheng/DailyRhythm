import 'package:sqflite/sqflite.dart';

/// Schema v21: how hard an exercise felt, see SCHEMA.md. Additive and safe
/// to run more than once.
class SchemaV21 {
  SchemaV21._();

  static Future<void> apply(DatabaseExecutor db) async {
    final columns = await db.rawQuery("PRAGMA table_info('exercise_entries')");
    if (!columns.any((c) => c['name'] == 'rpe')) {
      await db.execute('ALTER TABLE exercise_entries ADD COLUMN rpe INTEGER');
    }
  }
}
