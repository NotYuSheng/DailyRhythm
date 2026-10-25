import 'dart:convert';

import '../../../../features/exercise/data/models/exercise_item.dart';
import '../../../../features/meals/data/models/food_item.dart';
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

