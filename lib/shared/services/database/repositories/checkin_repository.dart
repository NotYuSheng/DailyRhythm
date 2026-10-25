import 'package:sqflite/sqflite.dart';

import '../../../models/day_checkin.dart';
import '../../../utils/date_utils.dart';
import '../database_service.dart';

/// One check-in per day: relative ratings and the garden plant override.
class CheckinRepository {
  CheckinRepository([DatabaseService? db]) : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  /// Creates or replaces the check-in for its day.
  Future<void> save(DayCheckin checkin) async {
    final db = await _db.database;
    final map = checkin.toMap()..['date'] = dayOf(checkin.date).toIso8601String();
    await db.insert('day_checkins', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DayCheckin?> forDay(DateTime day) async {
    final db = await _db.database;
    final rows = await db.query('day_checkins', where: 'date = ?', whereArgs: [dayOf(day).toIso8601String()]);
    return rows.isEmpty ? null : DayCheckin.fromMap(rows.first);
  }

  Future<List<DayCheckin>> inRange(DateTime start, DateTime end) async {
    final db = await _db.database;
    final to = dayOf(end);
    final rows = await db.query(
      'day_checkins',
      where: 'date >= ? AND date < ?',
      whereArgs: [dayOf(start).toIso8601String(), DateTime(to.year, to.month, to.day + 1).toIso8601String()],
      orderBy: 'date ASC',
    );
    return rows.map(DayCheckin.fromMap).toList();
  }
}
