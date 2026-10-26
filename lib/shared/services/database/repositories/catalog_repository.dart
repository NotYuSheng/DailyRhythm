import 'dart:convert';

import '../../../../features/exercise/data/models/exercise_item.dart';
import '../../../../features/meals/data/models/food_item.dart';
import '../../../../features/meals/domain/food_matcher.dart';
import '../database_service.dart';

/// Canonical foods and exercises, with aliases, for autocomplete.
class CatalogRepository {
  CatalogRepository([DatabaseService? db]) : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  // ==================== Foods ====================

  /// Inserts [item], or merges it into the food with the same name
  /// (aliases are combined; non-null fields overwrite). Returns its id.
  Future<int> saveFood(FoodItem item) async {
    final db = await _db.database;
    return db.transaction((txn) async {
      final existing = await txn.query('food_items', where: 'name = ?', whereArgs: [item.name]);
      if (existing.isEmpty) {
        final map = item.toMap()..remove('id');
        return txn.insert('food_items', map);
      }
      final current = FoodItem.fromMap(existing.first);
      final aliases = {...current.aliases, ...item.aliases}..remove(current.name);
      await txn.update(
        'food_items',
        {
          'aliases': jsonEncode(aliases.toList()..sort()),
          'kcal': item.kcal ?? current.kcal,
          'kcal_source': item.kcalSource ?? current.kcalSource,
          'last_price': item.lastPrice ?? current.lastPrice,
        },
        where: 'id = ?',
        whereArgs: [current.id],
      );
      return current.id!;
    });
  }

  /// The food whose name or alias matches [name], ignoring case.
  Future<FoodItem?> findFood(String name) async {
    final row = await _find('food_items', name);
    return row == null ? null : FoodItem.fromMap(row);
  }

  /// Foods matching [query], names starting with it first, then the most
  /// logged. An empty query returns the most logged foods.
  Future<List<FoodItem>> searchFoods(String query, {int limit = 8}) async {
    final rows = await _search('food_items', 'meal_entries', 'food_item_id', query, limit);
    return rows.map(FoodItem.fromMap).toList();
  }

  /// Every food with how often it has been logged, most logged first.
  Future<List<FoodChoice>> foodsWithUses() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT f.*, (SELECT COUNT(*) FROM meal_entries m WHERE m.food_item_id = f.id) AS uses
      FROM food_items f ORDER BY uses DESC, f.name
    ''');
    return [for (final r in rows) FoodChoice(FoodItem.fromMap(r), r['uses'] as int)];
  }

  /// Foods logged most over the [days] before [day], most recent breaking
  /// ties, leaving out ones already logged on [day]: likely next meals.
  Future<List<FoodChoice>> usualFoods(DateTime day, {int days = 30, int limit = 8}) async {
    final db = await _db.database;
    final start = DateTime(day.year, day.month, day.day - days).toIso8601String();
    final today = DateTime(day.year, day.month, day.day).toIso8601String();
    final rows = await db.rawQuery('''
      SELECT f.*, COUNT(*) AS uses, MAX(m.date) AS last
      FROM meal_entries m JOIN food_items f ON f.id = m.food_item_id
      WHERE m.date >= ? AND m.date < ?
        AND f.id NOT IN (SELECT food_item_id FROM meal_entries WHERE date = ? AND food_item_id IS NOT NULL)
      GROUP BY f.id
      ORDER BY uses DESC, last DESC
      LIMIT ?
    ''', [start, today, today, limit]);
    return [for (final r in rows) FoodChoice(FoodItem.fromMap(r), r['uses'] as int)];
  }

  // ==================== Exercises ====================

  Future<int> saveExercise(ExerciseItem item) async {
    final db = await _db.database;
    return db.transaction((txn) async {
      final existing = await txn.query('exercise_items', where: 'name = ?', whereArgs: [item.name]);
      if (existing.isEmpty) {
        final map = item.toMap()..remove('id');
        return txn.insert('exercise_items', map);
      }
      final current = ExerciseItem.fromMap(existing.first);
      final aliases = {...current.aliases, ...item.aliases}..remove(current.name);
      await txn.update(
        'exercise_items',
        {'aliases': jsonEncode(aliases.toList()..sort()), 'category': item.category},
        where: 'id = ?',
        whereArgs: [current.id],
      );
      return current.id!;
    });
  }

  Future<ExerciseItem?> findExercise(String name) async {
    final row = await _find('exercise_items', name);
    return row == null ? null : ExerciseItem.fromMap(row);
  }

  Future<List<ExerciseItem>> searchExercises(String query, {int limit = 8}) async {
    final rows = await _search('exercise_items', 'exercise_entries', 'exercise_item_id', query, limit);
    return rows.map(ExerciseItem.fromMap).toList();
  }

  // ==================== Shared ====================

  Future<Map<String, Object?>?> _find(String table, String name) async {
    final db = await _db.database;
    final byName = await db.query(table, where: 'name = ?', whereArgs: [name.trim()], limit: 1);
    if (byName.isNotEmpty) return byName.first;
    // Aliases are a JSON array; match the quoted, lower-cased alias.
    final needle = '%${jsonEncode(name.trim().toLowerCase())}%';
    final byAlias = await db.query(table, where: 'lower(aliases) LIKE ?', whereArgs: [needle], limit: 1);
    return byAlias.isEmpty ? null : byAlias.first;
  }

  Future<List<Map<String, Object?>>> _search(
    String table,
    String usageTable,
    String usageColumn,
    String query,
    int limit,
  ) async {
    final db = await _db.database;
    final q = query.trim().toLowerCase().replaceAll('%', '').replaceAll('_', '');
    return db.rawQuery(
      '''
      SELECT t.*, (SELECT COUNT(*) FROM $usageTable u WHERE u.$usageColumn = t.id) AS uses
      FROM $table t
      WHERE lower(t.name) LIKE ? OR lower(t.aliases) LIKE ?
      ORDER BY (lower(t.name) LIKE ?) DESC, uses DESC, t.name ASC
      LIMIT ?
      ''',
      ['%$q%', '%$q%', '$q%', limit],
    );
  }
}

