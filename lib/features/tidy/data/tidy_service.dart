import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/database/database_service.dart';
import '../../../shared/services/database/repositories/catalog_repository.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../shared/utils/name_case.dart';
import '../../ai/data/ai_client.dart';
import '../../meals/data/models/food_item.dart';
import '../../meals/data/models/meal_entry.dart';
import '../domain/tidy_item.dart';

typedef TidyProgress = void Function(int done, int total);

/// Finds what's worth tidying in a range of entries, asks the AI for more
/// if wanted, and applies the fixes the user keeps.
class TidyService {
  TidyService(this._db);

  final DatabaseService _db;

  static const _dismissedKey = 'tidy_dismissed';

  /// Side-like foods, which logged on their own usually belong to a meal.
  static final _sideLike = RegExp(
    r'\b(?:fries|wedges|hash ?browns?|nuggets?|wings?|mc ?wings|coleslaw|corn|onion rings|drink|coke|pepsi|sprite|milo|egg|plain egg|rice|extra rice|bun|bao|soup|salad)\b',
    caseSensitive: false,
  );

  /// Names that may be two foods: "X with Y", "X w Y", "X + Y", "X, Y".
  static final _combined = RegExp(r'\s(?:w/?|with|\+|&)\s|,\s*\S', caseSensitive: false);

  Future<Set<String>> dismissed() async => (await SharedPreferences.getInstance()).getStringList(_dismissedKey)?.toSet() ?? {};

  Future<void> dismiss(Iterable<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dismissedKey, {...?prefs.getStringList(_dismissedKey), ...keys}.toList());
  }

  Future<List<MealEntry>> _meals(DateTime start, DateTime end) async {
    final db = await _db.database;
    final last = dayOf(end);
    final rows = await db.query(
      'meal_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [dayOf(start).toIso8601String(), DateTime(last.year, last.month, last.day + 1).toIso8601String()],
      orderBy: 'date, time, id',
    );
    return rows.map(MealEntry.fromMap).toList();
  }

  /// The checks that need nothing but the entries.
  Future<TidyReport> check(DateTime start, DateTime end) async {
    final meals = await _meals(start, end);
    final foods = {for (final f in await CatalogRepository(_db).searchFoods('', limit: 1 << 20)) f.id: f};
    final skip = await dismissed();
    final fixes = <TidyFix>[];
    final flags = <TidyFlag>[];
    final byDay = <DateTime, List<MealEntry>>{};
    for (final m in meals) {
      (byDay[dayOf(m.date)] ??= []).add(m);
    }
    final hasSides = {for (final m in meals) ?m.sideOf};
    for (final day in byDay.values) {
      for (final (i, m) in day.indexed) {
        final food = foods[m.foodItemId];
        // A side-like food on its own, next to a meal of that sitting.
        if (!m.isSide && !hasSides.contains(m.id) && _sideLike.hasMatch(m.name)) {
          final main = _mainFor(m, day);
          if (main != null) fixes.add(TidyFix.side(mealId: m.id!, name: m.name, date: m.date, mainId: main.id!, mainName: main.name));
        }
        if (_combined.hasMatch(m.name) && !hasSides.contains(m.id)) {
          flags.add(TidyFlag(mealId: m.id!, name: m.name, date: m.date, reason: 'May be two foods; the AI can split it'));
        }
        // Same food twice within a couple of minutes.
        if (i > 0 && day[i - 1].name.toLowerCase() == m.name.toLowerCase() && m.time.difference(day[i - 1].time).inMinutes.abs() <= 2) {
          flags.add(TidyFlag(mealId: m.id!, name: m.name, date: m.date, reason: 'Logged twice?'));
        }
        if (!m.isSide && m.price == null && food?.lastPrice != null && m.foodSource != 'free' && m.foodSource != 'homemade') {
          flags.add(TidyFlag(mealId: m.id!, name: m.name, date: m.date, reason: 'No price; usually \$${food!.lastPrice!.toStringAsFixed(2)}'));
        }
        if (m.price case final price? when price > 0) {
          final usual = food?.lastPrice;
          if (usual != null && usual > 0 && (price / m.quantity > usual * 2.5 || price / m.quantity < usual * 0.4)) {
            flags.add(TidyFlag(mealId: m.id!, name: m.name, date: m.date, reason: '\$${price.toStringAsFixed(2)}; usually \$${usual.toStringAsFixed(2)}'));
          }
        }
      }
    }
    return TidyReport(
      fixes: [for (final f in fixes) if (!skip.contains(f.key)) f],
      flags: [for (final f in flags) if (!skip.contains(f.key)) f],
    );
  }

  /// The meal a lone side most likely came with: the nearest non-side on
  /// its day, within half an hour when times are known.
  static MealEntry? _mainFor(MealEntry side, List<MealEntry> day) {
    MealEntry? best;
    var gap = 1 << 30;
    for (final m in day) {
      if (m.id == side.id || m.isSide || _sideLike.hasMatch(m.name) || m.isSnack != side.isSnack) continue;
      final g = m.time.difference(side.time).inMinutes.abs();
      if (side.timeKnown && m.timeKnown && g > 30) continue;
      if (g < gap) (best, gap) = (m, g);
    }
    return best;
  }

  /// Asks the AI about the foods' names (only the names are sent): meal or
  /// snack, two foods in one, and brand.
  Future<List<TidyFix>> askAi(AiClient ai, DateTime start, DateTime end, {TidyProgress? progress}) async {
    final meals = [for (final m in await _meals(start, end)) if (!m.isSide) m];
    final hasSides = {for (final m in await _meals(start, end)) ?m.sideOf};
    final names = {for (final m in meals) m.name}.toList();
    final foods = {for (final f in await CatalogRepository(_db).searchFoods('', limit: 1 << 20)) f.name.toLowerCase(): f};
    final answers = <String, Map<String, dynamic>>{};
    const size = 20;
    for (var i = 0; i < names.length; i += size) {
      final batch = names.sublist(i, math.min(i + size, names.length));
      progress?.call(i, names.length);
      try {
        final reply = await ai.complete(system: _prompt, user: batch.join('\n'), quick: true);
        final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(reply);
        final list = match == null ? null : jsonDecode(match.group(0)!);
        if (list is List && list.length == batch.length) {
          for (final (j, a) in list.indexed) {
            if (a is Map<String, dynamic>) answers[batch[j]] = a;
          }
        }
      } on FormatException {
        // A garbled reply skips its batch.
      }
    }
    progress?.call(names.length, names.length);
    final skip = await dismissed();
    final fixes = <TidyFix>[];
    final branded = <String>{};
    for (final m in meals) {
      final a = answers[m.name];
      if (a == null) continue;
      final parts = [for (final p in (a['parts'] as List?) ?? const []) if (p is String && p.trim().isNotEmpty) tidyName(p.trim())];
      if (parts.length > 1 && !hasSides.contains(m.id)) {
        fixes.add(TidyFix.split(mealId: m.id!, name: m.name, date: m.date, parts: parts));
      }
      if (a['kind'] == 'snack' && !m.isSnack) fixes.add(TidyFix.kind(mealId: m.id!, name: m.name, date: m.date, kind: 'snack'));
      final brand = a['brand'];
      if (brand is String && brand.trim().isNotEmpty && foods[m.name.toLowerCase()]?.brand == null && branded.add(m.name.toLowerCase())) {
        fixes.add(TidyFix.brand(name: m.name, brand: brand.trim()));
      }
    }
    return [for (final f in fixes) if (!skip.contains(f.key)) f];
  }

  static const _prompt =
      'You tidy a food diary from Singapore. For each line (one food as logged) answer:\n'
      '- "kind": "meal" or "snack" (snacks, desserts, drinks, bread, kueh, fruit, small bites).\n'
      '- "parts": only when the line joins separately ordered items ("McSpicy with 4 pc nuggets" -> ["McSpicy", "4 pc nuggets"]), '
      'the main first; [] for one dish even with "and"/"with" ("Fish and chips", "Chicken rice", "Maggi with egg").\n'
      '- "brand": the chain or brand it is clearly from ("McDonald\'s", "KFC", "Old Chang Kee"), or null for a generic dish.\n'
      'Reply with only a JSON array, one object per line in order: {"kind": ..., "parts": [...], "brand": ...}.';

  /// Suggestions from a file (made on a computer from an export), checked
  /// against what's here: a meal that's gone or renamed is left out.
  Future<List<TidyFix>> load(String json) async {
    final decoded = jsonDecode(json);
    final list = decoded is Map ? decoded['fixes'] : decoded;
    if (list is! List) throw const FormatException('Not a suggestions file');
    final db = await _db.database;
    final names = {for (final r in await db.query('meal_entries', columns: ['id', 'name'])) r['id'] as int: r['name'] as String};
    final skip = await dismissed();
    return [
      for (final j in list.whereType<Map<String, dynamic>>())
        if (TidyFix.fromJson(j) case final fix?)
          if ((fix.mealId == null || names[fix.mealId]?.toLowerCase() == fix.name!.toLowerCase()) &&
              (fix.mainId == null || names.containsKey(fix.mainId)) &&
              !skip.contains(fix.key))
            fix,
    ];
  }

  /// Applies [fixes] in [TidyFix.types] order.
  /// Returns how many changed something.
  Future<int> apply(List<TidyFix> fixes, {TidyProgress? progress}) async {
    final catalog = CatalogRepository(_db);
    final db = await _db.database;
    final ordered = [for (final t in TidyFix.types) ...fixes.where((f) => f.type == t)];
    var applied = 0;
    for (final (i, fix) in ordered.indexed) {
      if (i % 25 == 0) progress?.call(i, ordered.length);
      final rows = fix.mealId == null ? const <Map<String, Object?>>[] : await db.query('meal_entries', where: 'id = ?', whereArgs: [fix.mealId]);
      final meal = rows.isEmpty ? null : MealEntry.fromMap(rows.single);
      switch (fix.type) {
        case TidyFix.brandType:
          final food = await catalog.findFood(fix.name!);
          if (food != null && food.brand == null) {
            await catalog.saveFood(FoodItem(name: food.name, brand: fix.brand));
            applied++;
          }
        case TidyFix.kindType when meal != null && !meal.isSide:
          await db.update('meal_entries', {'kind': fix.kind}, where: 'id = ? OR side_of = ?', whereArgs: [meal.id, meal.id]);
          applied++;
        case TidyFix.splitType when meal != null && !meal.isSide:
          // Foods first: the catalog has its own transactions.
          final foodIds = [for (final part in fix.parts) await catalog.saveFood(FoodItem(name: part))];
          await db.transaction((txn) async {
            await txn.update('meal_entries', {'name': tidyName(fix.parts.first), 'food_item_id': foodIds.first}, where: 'id = ?', whereArgs: [meal.id]);
            for (final (j, part) in fix.parts.indexed.skip(1)) {
              final food = foodIds[j];
              await txn.insert(
                'meal_entries',
                (MealEntry(
                  date: meal.date,
                  time: meal.time,
                  name: tidyName(part),
                  foodSource: meal.foodSource,
                  foodItemId: food,
                  currency: meal.currency,
                  timeKnown: meal.timeKnown,
                  kind: meal.kind,
                  sideOf: meal.id,
                ).toMap())
                  ..remove('id'),
              );
            }
            await _dropUnusedFood(txn, meal.foodItemId);
          });
          applied++;
        case TidyFix.sideType when meal != null && !meal.isSide:
          final main = await db.query('meal_entries', where: 'id = ? AND side_of IS NULL', whereArgs: [fix.mainId]);
          if (main.isEmpty) break;
          final m = MealEntry.fromMap(main.single);
          await db.update(
            'meal_entries',
            {'side_of': m.id, 'time': m.time.toIso8601String(), 'kind': m.kind, 'time_known': m.timeKnown ? 1 : 0},
            where: 'id = ?',
            whereArgs: [meal.id],
          );
          applied++;
      }
    }
    progress?.call(ordered.length, ordered.length);
    return applied;
  }

  static Future<void> _dropUnusedFood(dynamic txn, int? foodId) async {
    if (foodId == null) return;
    await txn.rawDelete('DELETE FROM food_items WHERE id = ? AND NOT EXISTS (SELECT 1 FROM meal_entries WHERE food_item_id = ?)', [foodId, foodId]);
  }
}
