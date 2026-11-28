import '../../../shared/services/database/database_service.dart';
import '../../../shared/utils/date_utils.dart';
import 'learning_entry.dart';

/// What was learnt, by day.
class LearningRepository {
  LearningRepository([DatabaseService? db]) : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  /// Inserts [entry], or updates it when it has an id. Returns its id.
  Future<int> save(LearningEntry entry) async {
    final db = await _db.database;
    final map = entry.toMap()..['date'] = dayOf(entry.date).toIso8601String();
    if (entry.id == null) {
      map.remove('id');
      return db.insert('learning_entries', map);
    }
    await db.update('learning_entries', map, where: 'id = ?', whereArgs: [entry.id]);
    return entry.id!;
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('learning_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<LearningEntry>> forDay(DateTime day) => inRange(day, day);

  Future<List<LearningEntry>> inRange(DateTime start, DateTime end) async {
    final db = await _db.database;
    final last = dayOf(end);
    final rows = await db.query(
      'learning_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [dayOf(start).toIso8601String(), DateTime(last.year, last.month, last.day + 1).toIso8601String()],
      orderBy: 'date, time, id',
    );
    return rows.map(LearningEntry.fromMap).toList();
  }

  Future<List<LearningEntry>> all() async {
    final db = await _db.database;
    return (await db.query('learning_entries', orderBy: 'date, time, id')).map(LearningEntry.fromMap).toList();
  }

  /// Topics used so far, the most used first.
  Future<List<String>> topics() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      "SELECT topic FROM learning_entries WHERE topic IS NOT NULL AND topic != '' GROUP BY topic ORDER BY COUNT(*) DESC, MAX(date) DESC",
    );
    return [for (final r in rows) r['topic'] as String];
  }
}
