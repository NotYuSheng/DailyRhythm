import '../../../models/spending_entry.dart';
import '../../../utils/date_utils.dart';
import '../database_service.dart';

/// Events and gifts: spending that isn't a meal.
class SpendingRepository {
  SpendingRepository([DatabaseService? db]) : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  /// Inserts [entry], or updates it when it has an id. Returns its id.
  Future<int> save(SpendingEntry entry) async {
    final db = await _db.database;
    final map = entry.toMap()..['date'] = dayOf(entry.date).toIso8601String();
    if (entry.id == null) {
      map.remove('id');
      return db.insert('spending_entries', map);
    }
    await db.update('spending_entries', map, where: 'id = ?', whereArgs: [entry.id]);
    return entry.id!;
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('spending_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SpendingEntry>> forDay(DateTime day) => inRange(day, day);

  Future<List<SpendingEntry>> inRange(DateTime start, DateTime end) async {
    final db = await _db.database;
    final last = dayOf(end);
    final rows = await db.query(
      'spending_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [dayOf(start).toIso8601String(), DateTime(last.year, last.month, last.day + 1).toIso8601String()],
      orderBy: 'date, time, id',
    );
    return rows.map(SpendingEntry.fromMap).toList();
  }
}
