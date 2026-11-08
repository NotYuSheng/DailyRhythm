import 'dart:convert';

import '../../../../features/exercise/data/models/exercise_entry.dart';
import '../../../../features/exercise/data/models/exercise_item.dart';
import '../../../../features/exercise/domain/exercise_matcher.dart';
import '../../../../features/meals/data/models/food_item.dart';
import '../../../../features/meals/domain/diet_score.dart';
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
  Future<List<FoodChoice>> foodsWithUses() async => [
        for (final r in await _withUses('food_items', 'meal_entries', 'food_item_id'))
          FoodChoice(FoodItem.fromMap(r), r['uses'] as int),
      ];

  /// Foods logged most over the [days] before [day], most recent breaking
  /// ties, leaving out ones already logged on [day]: likely next meals.
  Future<List<FoodChoice>> usualFoods(DateTime day, {int days = 30, int limit = 8}) async => [
        for (final r in await _usual('food_items', 'meal_entries', 'food_item_id', day, days, limit))
          FoodChoice(FoodItem.fromMap(r), r['uses'] as int),
      ];

  /// Sets (or with null clears) the health score categories the user chose
  /// for a food, for every meal of it without its own.
  Future<void> setFoodHealthTags(int foodId, List<String>? tags) async {
    final db = await _db.database;
    await db.update('food_items', {'health_tags': DietScore.encodeTags(tags)}, where: 'id = ?', whereArgs: [foodId]);
  }

  /// Health score categories the user set, by food id.
  Future<Map<int, List<String>>> foodHealthTags() async {
    final db = await _db.database;
    final rows = await db.query('food_items', columns: ['id', 'health_tags'], where: 'health_tags IS NOT NULL');
    return {for (final r in rows) r['id'] as int: DietScore.decodeTags(r['health_tags'])!};
  }

  /// Calories per serving of every food that has them, by food id.
  Future<Map<int, double>> foodCalories() async {
    final db = await _db.database;
    final rows = await db.query('food_items', columns: ['id', 'kcal'], where: 'kcal IS NOT NULL');
    return {for (final r in rows) r['id'] as int: (r['kcal'] as num).toDouble()};
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
        // The category already known stays: callers often pass the default.
        {'aliases': jsonEncode(aliases.toList()..sort())},
        where: 'id = ?',
        whereArgs: [current.id],
      );
      return current.id!;
    });
  }

  /// Every exercise with how often it has been logged, most logged first.
  Future<List<ExerciseChoice>> exercisesWithUses() async => [
        for (final r in await _withUses('exercise_items', 'exercise_entries', 'exercise_item_id'))
          ExerciseChoice(ExerciseItem.fromMap(r), r['uses'] as int),
      ];

  /// Exercises logged most over the [days] before [day], leaving out ones
  /// already logged on [day]: likely next exercises.
  Future<List<ExerciseChoice>> usualExercises(DateTime day, {int days = 30, int limit = 8}) async => [
        for (final r in await _usual('exercise_items', 'exercise_entries', 'exercise_item_id', day, days, limit))
          ExerciseChoice(ExerciseItem.fromMap(r), r['uses'] as int),
      ];

  /// The latest entry for the exercise [itemId], to prefill the next one.
  Future<ExerciseEntry?> lastExercise(int itemId) async {
    final db = await _db.database;
    final rows = await db.query(
      'exercise_entries',
      where: 'exercise_item_id = ?',
      whereArgs: [itemId],
      orderBy: 'date DESC, timestamp DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ExerciseEntry.fromMap(rows.first);
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

  /// Every row of [table] with how many [entries] link to it.
  Future<List<Map<String, Object?>>> _withUses(String table, String entries, String link) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT t.*, (SELECT COUNT(*) FROM $entries e WHERE e.$link = t.id) AS uses
      FROM $table t ORDER BY uses DESC, t.name
    ''');
  }

  /// Rows of [table] most linked from [entries] over the [days] before
  /// [day], most recent breaking ties, leaving out ones linked on [day].
  Future<List<Map<String, Object?>>> _usual(String table, String entries, String link, DateTime day, int days, int limit) async {
    final db = await _db.database;
    final start = DateTime(day.year, day.month, day.day - days).toIso8601String();
    final today = DateTime(day.year, day.month, day.day).toIso8601String();
    return db.rawQuery('''
      SELECT t.*, COUNT(*) AS uses, MAX(e.date) AS last
      FROM $entries e JOIN $table t ON t.id = e.$link
      WHERE e.date >= ? AND e.date < ?
        AND t.id NOT IN (SELECT $link FROM $entries WHERE date = ? AND $link IS NOT NULL)
      GROUP BY t.id
      ORDER BY uses DESC, last DESC
      LIMIT ?
    ''', [start, today, today, limit]);
  }

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

