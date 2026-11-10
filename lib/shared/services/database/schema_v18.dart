import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../utils/name_case.dart';

/// Schema v18: food and exercise names in one style ([tidyName]), and no
/// catalog items left that nothing uses, see SCHEMA.md. Safe to run more
/// than once.
class SchemaV18 {
  SchemaV18._();

  static Future<void> apply(DatabaseExecutor db) async {
    await _tidy(db, items: 'food_items', entries: 'meal_entries', link: 'food_item_id', entryName: 'name');
    await _tidy(db, items: 'exercise_items', entries: 'exercise_entries', link: 'exercise_item_id', entryName: 'exerciseName');
  }

  static Future<void> _tidy(DatabaseExecutor db, {required String items, required String entries, required String link, required String entryName}) async {
    for (final row in await db.query(items, orderBy: 'id')) {
      final id = row['id'] as int;
      final name = row['name'] as String;
      final tidy = tidyName(name);
      if (tidy == name || tidy.isEmpty) continue;
      // Tidying can make two names the same ("Mixed  rice", "Mixed rice"):
      // the later one joins the earlier.
      final same = await db.query(items, where: 'name = ? AND id != ?', whereArgs: [tidy, id]);
      if (same.isEmpty) {
        await db.update(items, {'name': tidy}, where: 'id = ?', whereArgs: [id]);
        continue;
      }
      final keep = same.first;
      final aliases = {
        ..._aliases(keep['aliases']),
        ..._aliases(row['aliases']),
        name,
      }..removeWhere((a) => a.toLowerCase() == tidy.toLowerCase());
      await db.update(items, {'aliases': jsonEncode(aliases.toList()..sort())}, where: 'id = ?', whereArgs: [keep['id']]);
      await db.update(entries, {link: keep['id']}, where: '$link = ?', whereArgs: [id]);
      await db.delete(items, where: 'id = ?', whereArgs: [id]);
    }
    for (final row in await db.rawQuery('SELECT DISTINCT $entryName AS n FROM $entries WHERE $entryName IS NOT NULL')) {
      final name = row['n'] as String;
      final tidy = tidyName(name);
      if (tidy != name && tidy.isNotEmpty) await db.update(entries, {entryName: tidy}, where: '$entryName = ?', whereArgs: [name]);
    }
    await db.delete(items, where: 'id NOT IN (SELECT $link FROM $entries WHERE $link IS NOT NULL)');
  }

  static Iterable<String> _aliases(Object? stored) {
    final text = (stored as String?)?.trim() ?? '';
    if (text.startsWith('[')) return (jsonDecode(text) as List).cast<String>();
    return [for (final a in text.split(';')) if (a.trim().isNotEmpty) a.trim()];
  }
}
