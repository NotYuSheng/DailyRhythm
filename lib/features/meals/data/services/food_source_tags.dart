import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../../shared/services/database/database_service.dart';
import '../../../ai/data/ai_client.dart';
import '../../../tags/data/models/tag.dart';
import '../models/meal_entry.dart';

/// A meal on a day with old food-source tags, still without a source.
class SourcelessMeal {
  const SourcelessMeal({required this.id, required this.name, this.time});

  final int id;
  final String name;

  /// "12:30", or null when the time isn't known.
  final String? time;
}

/// A day tagged, as a whole, with where its food came from.
class SourceDay {
  const SourceDay({required this.date, required this.sources, required this.meals});

  /// yyyy-MM-dd.
  final String date;

  /// [FoodSource] values.
  final Set<String> sources;
  final List<SourcelessMeal> meals;
}

/// What moving the old tags did.
class SourceTagMoveResult {
  const SourceTagMoveResult({required this.mealsSet, required this.daysSkipped});

  final int mealsSet;

  /// Tagged days where no meal got a source (none logged, or none fit).
  final int daysSkipped;
}

/// Meals record where they came from, so the old day-level "Food from"
/// tags (mostly from Daylio) are moved onto meals and then deleted.
///
/// A day with one source and one meal is obvious. The rest are given to
/// the AI assistant, which matches tags to meals by name and time.
class FoodSourceTags {
  FoodSourceTags(this.db);

  final DatabaseService db;

  /// Days per AI request.
  static const batch = 10;

  /// How long one batch may take: a thinking model can need a minute or more.
  static const timeout = Duration(minutes: 3);

  /// The meal source an old tag stands for; null for one with none
  /// (Supplement), which is deleted without moving.
  static String? sourceFor(String tagName) => switch (tagName.trim().toLowerCase()) {
        'takeout' || 'take out' || 'takeaway' => FoodSource.takeout,
        'fast food' => FoodSource.fastFood,
        'homemade' || 'home cooked' || 'home-cooked' => FoodSource.homemade,
        'free food' || 'free' => FoodSource.free,
        'restaurant' => FoodSource.restaurant,
        'food court' || 'hawker' => FoodSource.foodCourt,
        'delivery' => FoodSource.delivery,
        _ => null,
      };

  /// Whether any old food-source tags are left.
  Future<bool> any() async {
    final d = await db.database;
    return (await d.query('tags', columns: ['id'], where: 'kind = ?', whereArgs: [TagKind.foodSource], limit: 1)).isNotEmpty;
  }

  /// Every day with a movable tag, with its meals that have no source yet.
  Future<List<SourceDay>> days() async {
    final d = await db.database;
    final rows = await d.rawQuery('''
      SELECT substr(a.date, 1, 10) AS day, t.name AS name
      FROM activity_entries a JOIN tags t ON t.id = a.tagId
      WHERE t.kind = ?
    ''', [TagKind.foodSource]);
    final sources = <String, Set<String>>{};
    for (final r in rows) {
      if (sourceFor(r['name'] as String) case final s?) (sources[r['day'] as String] ??= {}).add(s);
    }
    if (sources.isEmpty) return const [];
    final meals = <String, List<SourcelessMeal>>{};
    for (final r in await d.rawQuery('''
      SELECT id, substr(date, 1, 10) AS day, time, time_known, name FROM meal_entries
      WHERE food_source IS NULL OR food_source = ''
      ORDER BY sort_order IS NULL, sort_order, time, id
    ''')) {
      final day = r['day'] as String;
      if (!sources.containsKey(day)) continue;
      final time = r['time'] as String?;
      (meals[day] ??= []).add(SourcelessMeal(
        id: r['id'] as int,
        name: (r['name'] as String?) ?? '',
        time: r['time_known'] == 0 || time == null || time.length < 16 ? null : time.substring(11, 16),
      ));
    }
    return [
      for (final e in (sources.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
        SourceDay(date: e.key, sources: e.value, meals: meals[e.key] ?? const []),
    ];
  }

  /// One source and one meal: that meal is the one.
  static Map<int, String> obvious(Iterable<SourceDay> days) => {
        for (final d in days)
          if (d.sources.length == 1 && d.meals.length == 1) d.meals.single.id: d.sources.single,
      };

  /// The days the AI is needed for.
  static List<SourceDay> unclear(Iterable<SourceDay> days) =>
      [for (final d in days) if (d.meals.isNotEmpty && !(d.sources.length == 1 && d.meals.length == 1)) d];

  static const _system = 'Each day below was tagged, as a whole, with where some of its food came from. '
      'Work out which meals each tag was about, from the meal names and times. '
      'Sources: takeout (bought and taken away), fast_food (burger, fried chicken or pizza chains and the like), '
      'homemade (cooked at home), free (given or treated), restaurant (sit-down), food_court (hawker centre, '
      'food court, coffee shop stall), delivery (delivered). '
      'Rules: only use a source tagged on that day; give each tag to at least one meal of that day when any fits; '
      'a meal gets at most one source; leave a meal out when no tag fits it (a snack or drink often has none). '
      'Answer with only a JSON object: {"meals": {"<meal id>": "<source>", ...}}. No other text.';

  /// The prompt lines for [days]: "2026-03-04 | tags: takeout | 12 08:10 Kaya Toast; 13 Chicken Rice".
  static String describe(Iterable<SourceDay> days) => [
        for (final d in days)
          '${d.date} | tags: ${d.sources.join(', ')} | '
              '${d.meals.map((m) => '${m.id}${m.time == null ? '' : ' ${m.time}'} ${m.name}').join('; ')}',
      ].join('\n');

  /// Reads the AI's answer, keeping only matches the rules allow.
  static Map<int, String> parse(String answer, Iterable<SourceDay> days) {
    final start = answer.indexOf('{'), end = answer.lastIndexOf('}');
    if (start < 0 || end <= start) throw const AiException('The answer wasn’t in the expected format.');
    final Object? json;
    try {
      json = jsonDecode(answer.substring(start, end + 1));
    } catch (_) {
      throw const AiException('The answer wasn’t in the expected format.');
    }
    final meals = json is Map ? json['meals'] : null;
    if (meals is! Map) throw const AiException('The answer wasn’t in the expected format.');
    final allowed = {for (final d in days) for (final m in d.meals) m.id: d.sources};
    return {
      for (final MapEntry(:key, :value) in meals.entries)
        if (int.tryParse('$key') case final id? when value is String && (allowed[id]?.contains(value) ?? false)) id: value,
    };
  }

  /// Moves the tags onto meals, asking [ai] about the unclear days (needed
  /// when there are any, or they would be lost), then deletes every
  /// food-source tag with its history.
  ///
  /// Each batch is saved as it is answered, so if the AI fails part way the
  /// meals matched so far keep their source, the tags stay, and running it
  /// again carries on with the days left.
  Future<SourceTagMoveResult> run({AiClient? ai, void Function(int done, int total)? progress}) async {
    final all = await days();
    final ask = unclear(all);
    if (ask.isNotEmpty && ai == null) throw const AiException('Set up the AI assistant first.');
    final d = await db.database;
    Future<void> save(Map<int, String> picks) => d.transaction((txn) async {
          for (final MapEntry(key: id, value: source) in picks.entries) {
            await txn.update('meal_entries', {'food_source': source}, where: 'id = ?', whereArgs: [id]);
          }
        });
    final picks = obvious(all);
    await save(picks);
    for (var i = 0; i < ask.length; i += batch) {
      progress?.call(i, ask.length);
      final part = ask.sublist(i, i + batch > ask.length ? ask.length : i + batch);
      Map<int, String> found;
      try {
        found = await _ask(ai!, part);
      } on AiException {
        found = await _ask(ai!, part); // once more: a slow answer is often fine the second time
      }
      await save(found);
      picks.addAll(found);
    }
    progress?.call(ask.length, ask.length);
    await d.transaction((txn) async {
      final ids = [for (final r in await txn.query('tags', columns: ['id'], where: 'kind = ?', whereArgs: [TagKind.foodSource])) r['id'] as int];
      if (ids.isNotEmpty) {
        final list = ids.map((_) => '?').join(', ');
        await txn.delete('activity_entries', where: 'tagId IN ($list)', whereArgs: ids);
        await txn.delete('journal_entry_tags', where: 'tag_id IN ($list)', whereArgs: ids);
        await txn.delete('tags', where: 'id IN ($list)', whereArgs: ids);
      }
    });
    final done = {for (final d in all) for (final m in d.meals) if (picks.containsKey(m.id)) d.date};
    return SourceTagMoveResult(mealsSet: picks.length, daysSkipped: all.length - done.length);
  }

  Future<Map<int, String>> _ask(AiClient ai, List<SourceDay> part) async =>
      parse(await ai.complete(system: _system, user: describe(part), timeout: timeout), part);

  /// Brings the movable food-source tags, with the days they were on, back
  /// from the backup database at [path], leaving everything else as it is.
  /// Returns how many days were brought back.
  Future<int> recoverFrom(String path) async {
    final backup = await databaseFactory.openDatabase(path, options: OpenDatabaseOptions(readOnly: true, singleInstance: false));
    try {
      final hasKind = (await backup.rawQuery("PRAGMA table_info('tags')")).any((c) => c['name'] == 'kind');
      final old = [
        for (final t in await backup.query('tags', columns: ['id', 'name', 'emoji', 'category', if (hasKind) 'kind']))
          if (sourceFor(t['name'] as String) != null && (!hasKind || t['kind'] == TagKind.foodSource)) t,
      ];
      if (old.isEmpty) return 0;
      final columns = {for (final c in await backup.rawQuery("PRAGMA table_info('activity_entries')")) c['name'] as String};
      final entries = await backup.query(
        'activity_entries',
        columns: [for (final c in ['tagId', 'date', 'timestamp', 'notes', 'severity']) if (columns.contains(c)) c],
        where: 'tagId IN (${old.map((_) => '?').join(', ')})',
        whereArgs: [for (final t in old) t['id']],
      );
      final d = await db.database;
      var added = 0;
      await d.transaction((txn) async {
        final ids = <int, int>{};
        for (final t in old) {
          final same = await txn.query('tags', columns: ['id'], where: 'name = ?', whereArgs: [t['name']]);
          ids[t['id'] as int] = same.isNotEmpty
              ? same.first['id'] as int
              : await txn.insert('tags', {
                  'name': t['name'],
                  'emoji': t['emoji'] ?? 'tag',
                  'category': t['category'] ?? 'Food',
                  'kind': TagKind.foodSource,
                });
        }
        for (final e in entries) {
          final tagId = ids[e['tagId'] as int]!;
          final day = (e['date'] as String).substring(0, 10);
          final there = await txn.query('activity_entries', columns: ['id'], where: 'tagId = ? AND substr(date, 1, 10) = ?', whereArgs: [tagId, day], limit: 1);
          if (there.isNotEmpty) continue;
          await txn.insert('activity_entries', {...e, 'tagId': tagId});
          added++;
        }
      });
      return added;
    } finally {
      await backup.close();
    }
  }
}
