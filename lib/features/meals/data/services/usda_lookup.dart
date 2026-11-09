import 'dart:convert';

import 'calorie_lookup.dart';

/// USDA FoodData Central (SR Legacy, public domain), bundled for search
/// without a connection: `assets/data/usda_foods.json`, made by
/// `tool/usda/build_usda_foods.py`. Each food has kcal per 100 g and up to
/// two common portions.
class UsdaLookup implements CalorieLookup {
  UsdaLookup(this._load);

  /// Reads the bundled JSON; replaced in tests.
  final Future<String> Function() _load;
  List<_Food>? _foods;

  static const source = 'usda';

  Future<List<_Food>> _all() async => _foods ??= [
        for (final e in jsonDecode(await _load()) as List)
          _Food(
            e['n'] as String,
            (e['k'] as num).toDouble(),
            [for (final p in e['p'] as List? ?? const []) ((p as List)[0] as String, (p[1] as num).toDouble())],
          ),
      ];

  /// Lower case, letters and digits only, a trailing plural "s" dropped,
  /// so "Apple" finds "Apples, raw".
  static List<String> _words(String s) => [
        for (final w in s.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
          if (w.length > 1) w.length > 3 && w.endsWith('s') && !w.endsWith('ss') ? w.substring(0, w.length - 1) : w,
      ];

  @override
  Future<List<CalorieMatch>> search(String query) async {
    final wanted = _words(query);
    if (wanted.isEmpty) return const [];
    final scored = <(int, _Food)>[];
    for (final f in await _all()) {
      final words = f.words;
      if (!wanted.every((w) => words.any((x) => x == w || x.startsWith(w)))) continue;
      // Names that start with what was typed and have fewer extra words
      // first: "Apples, raw" before "Babyfood, apples, dessert".
      final starts = words.isNotEmpty && words.first.startsWith(wanted.first) ? 0 : 10;
      // USDA names a plain food "…, raw": "Apples, raw" before "Apple juice".
      final plain = words.contains('raw') && !wanted.contains('raw') ? -3 : 0;
      scored.add((starts + words.length + plain, f));
    }
    scored.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.name.length.compareTo(b.$2.name.length));
    return [
      for (final (_, f) in scored.take(15))
        if (f.portions.isNotEmpty)
          CalorieMatch(
            name: f.name,
            kcal: (f.kcal100 * f.portions.first.$2 / 100).roundToDouble(),
            basis: 'serving',
            serving: '${f.portions.first.$1} (${f.portions.first.$2.round()} g)',
            source: source,
          )
        else
          CalorieMatch(name: f.name, kcal: f.kcal100, basis: '100 g', source: source),
    ];
  }

  @override
  Future<CalorieMatch?> byBarcode(String code) async => null;
}

class _Food {
  _Food(this.name, this.kcal100, this.portions) : words = UsdaLookup._words(name);

  final String name;
  final double kcal100;
  final List<(String, double)> portions;
  final List<String> words;
}

/// Offline USDA results first, then Open Food Facts when online. A failed
/// online search doesn't hide what was found offline.
class CombinedLookup implements CalorieLookup {
  CombinedLookup(this.offline, this.online);

  final CalorieLookup offline;
  final CalorieLookup online;

  @override
  Future<List<CalorieMatch>> search(String query) async {
    final local = await offline.search(query);
    try {
      return [...local, ...await online.search(query)];
    } catch (_) {
      if (local.isEmpty) rethrow;
      return local;
    }
  }

  @override
  Future<CalorieMatch?> byBarcode(String code) => online.byBarcode(code);
}
