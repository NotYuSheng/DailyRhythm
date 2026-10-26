import 'package:sqflite/sqflite.dart';

import '../../../models/daylio_raw_entry.dart';
import '../../../utils/date_utils.dart';
import '../database_service.dart';

/// Original Daylio entries, stored verbatim alongside the parsed data.
class DaylioRawRepository {
  DaylioRawRepository([DatabaseService? db]) : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  /// Saves entries, skipping ones already stored (same day, time and note).
  Future<void> saveAll(List<DaylioRawEntry> entries) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final e in entries) {
      final map = e.toMap()..['date'] = dayOf(e.date).toIso8601String();
      batch.insert('daylio_raw', map, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<List<DaylioRawEntry>> forDay(DateTime day) async {
    final db = await _db.database;
    final rows = await db.query(
      'daylio_raw',
      where: 'date = ?',
      whereArgs: [dayOf(day).toIso8601String()],
      orderBy: 'logged_time ASC',
    );
    return rows.map(DaylioRawEntry.fromMap).toList();
  }
}
