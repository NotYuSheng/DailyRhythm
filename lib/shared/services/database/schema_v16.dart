import 'package:sqflite/sqflite.dart';

/// Schema v16: chores get their own group of activity tags, see SCHEMA.md.
/// Moves chore-like activity tags into "Chores". Safe to run more than once.
class SchemaV16 {
  SchemaV16._();

  static const group = 'Chores';

  /// Names that read as a chore (lower case, matched anywhere in the name).
  static const chores = [
    'bedsheet', 'laundry', 'clean', 'chore', 'grocer', 'dishes', 'vacuum', 'ironing', 'tidy', 'mop', 'trash', 'rubbish', 'declutter',
  ];

  static Future<void> apply(DatabaseExecutor db) async {
    final match = chores.map((_) => 'lower(name) LIKE ?').join(' OR ');
    final moved = await db.update('tags', {'category': group},
        where: "kind = 'activity' AND ($match)", whereArgs: [for (final c in chores) '%$c%']);
    final exists = (await db.query('tag_categories', where: 'name = ?', whereArgs: [group])).isNotEmpty;
    if (moved > 0 && !exists) {
      final last = (await db.rawQuery('SELECT MAX(sort_order) AS m FROM tag_categories')).first['m'] as int?;
      await db.insert('tag_categories', {'name': group, 'sort_order': (last ?? 0) + 1});
    }
  }
}
