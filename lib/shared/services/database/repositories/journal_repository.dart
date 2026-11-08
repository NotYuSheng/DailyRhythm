import 'package:sqflite/sqflite.dart';

import '../../../../features/journal/data/models/journal_entry.dart';
import '../../../utils/date_utils.dart';
import '../database_service.dart';

/// Journal moments and the tags they are about.
class JournalRepository {
  JournalRepository([DatabaseService? db]) : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  /// Inserts or updates [entry] and replaces its tags. Returns its id.
  Future<int> save(JournalEntry entry) async {
    final db = await _db.database;
    return db.transaction((txn) async {
      final map = entry.toMap()..['date'] = dayOf(entry.date).toIso8601String();
      int id;
      if (entry.id == null) {
        map.remove('id');
        id = await txn.insert('journal_entries', map);
      } else {
        id = entry.id!;
        await txn.update('journal_entries', map, where: 'id = ?', whereArgs: [id]);
        await txn.delete('journal_entry_tags', where: 'entry_id = ?', whereArgs: [id]);
      }
      for (final tagId in entry.tagIds.toSet()) {
        await txn.insert('journal_entry_tags', {'entry_id': id, 'tag_id': tagId});
      }
      return id;
    });
  }

  Future<List<JournalEntry>> forDay(DateTime day) => inRange(day, day);

  /// Entries on days from [start] to [end] inclusive, in time order
  /// (entries without a time last within their day).
  Future<List<JournalEntry>> inRange(DateTime start, DateTime end) async {
    final db = await _db.database;
    final from = dayOf(start);
    final to = dayOf(end);
    final rows = await db.query(
      'journal_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [from.toIso8601String(), DateTime(to.year, to.month, to.day + 1).toIso8601String()],
      orderBy: 'date ASC, time IS NULL, time ASC, id ASC',
    );
    return _withTags(db, rows);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('journal_entry_tags', where: 'entry_id = ?', whereArgs: [id]);
      await txn.delete('journal_entries', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<JournalEntry>> _withTags(DatabaseExecutor db, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r['id'] as int).toList();
    final links = await db.query(
      'journal_entry_tags',
      where: 'entry_id IN (${List.filled(ids.length, '?').join(', ')})',
      whereArgs: ids,
    );
    final tagsById = <int, List<int>>{};
    for (final link in links) {
      tagsById.putIfAbsent(link['entry_id'] as int, () => []).add(link['tag_id'] as int);
    }
    return [for (final row in rows) JournalEntry.fromMap(row, tagIds: tagsById[row['id']] ?? const [])];
  }
}
