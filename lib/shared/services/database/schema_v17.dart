import 'package:sqflite/sqflite.dart';

/// Schema v17: tidies activity tags, see SCHEMA.md. Safe to run more than
/// once.
///
/// - Tags that other logs now cover are deleted with the days they were
///   logged on: waking and sleeping early (bedtimes are tracked), intense
///   exercise (each exercise day gets an effort level) and naps.
/// - Occasional visits and one-offs (haircut, dentist, doctor, a cab…) get
///   their own group, "Appointments".
class SchemaV17 {
  SchemaV17._();

  static const group = 'Appointments';

  /// Activity tags deleted, with their history (names in lower case).
  static const retired = ['woke up early', 'slept early', 'intense exercise', 'nap'];

  /// Names that read as an appointment or one-off (lower case, matched
  /// anywhere in the name).
  static const appointments = ['haircut', 'barber', 'salon', 'dentist', 'doctor', 'clinic', 'check-up', 'checkup', 'appointment', 'cab', 'taxi'];

  static Future<void> apply(DatabaseExecutor db) async {
    final names = retired.map((_) => '?').join(', ');
    final ids = [
      for (final r in await db.query('tags', columns: ['id'], where: "kind = 'activity' AND lower(name) IN ($names)", whereArgs: retired))
        r['id'] as int,
    ];
    if (ids.isNotEmpty) {
      final list = ids.map((_) => '?').join(', ');
      await db.delete('activity_entries', where: 'tagId IN ($list)', whereArgs: ids);
      await db.delete('journal_entry_tags', where: 'tag_id IN ($list)', whereArgs: ids);
      await db.delete('tags', where: 'id IN ($list)', whereArgs: ids);
    }

    final match = appointments.map((_) => 'lower(name) LIKE ?').join(' OR ');
    final moved = await db.update('tags', {'category': group},
        where: "kind = 'activity' AND ($match)", whereArgs: [for (final a in appointments) '%$a%']);
    final exists = (await db.query('tag_categories', where: 'name = ?', whereArgs: [group])).isNotEmpty;
    if (moved > 0 && !exists) {
      final last = (await db.rawQuery('SELECT MAX(sort_order) AS m FROM tag_categories')).first['m'] as int?;
      await db.insert('tag_categories', {'name': group, 'sort_order': (last ?? 0) + 1});
    }
  }
}
