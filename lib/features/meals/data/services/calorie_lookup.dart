import 'dart:convert';

import 'package:http/http.dart' as http;

/// A food's calories from a reference source, for the user to confirm.
class CalorieMatch {
  const CalorieMatch({required this.name, required this.kcal, required this.basis, required this.source, this.brand});

  final String name;
  final String? brand;

  /// Calories per [basis].
  final double kcal;

  /// "serving" when the source gives a serving size, otherwise "100 g".
  final String basis;

  /// Where the value came from (see `docs/CALORIES.md`): usda, sgfoodid,
  /// off, estimate or user.
  final String source;
}

/// Looks up calories for a food by name.
abstract class CalorieLookup {
  Future<List<CalorieMatch>> search(String query);
}

/// Open Food Facts text search. Online and opt-in: only the typed name is
/// sent. Data is ODbL; the app shows the source next to each value.
class OpenFoodFactsLookup implements CalorieLookup {
  OpenFoodFactsLookup([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static const source = 'off';

  @override
  Future<List<CalorieMatch>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': q,
      'search_simple': '1',
      'json': '1',
      'page_size': '12',
      'fields': 'product_name,brands,nutriments,serving_size',
    });
    // Open Food Facts asks apps to identify themselves.
    final response = await _client
        .get(uri, headers: {'User-Agent': 'DailyRhythm/1.0 (personal tracker; github.com/NotYuSheng/DailyRhythm)'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Open Food Facts answered ${response.statusCode}');
    }
    final products = (jsonDecode(response.body) as Map<String, dynamic>)['products'] as List? ?? const [];
    final matches = <CalorieMatch>[];
    for (final p in products.cast<Map<String, dynamic>>()) {
      final name = (p['product_name'] as String?)?.trim();
      final nutriments = p['nutriments'] as Map<String, dynamic>? ?? const {};
      final perServing = _number(nutriments['energy-kcal_serving']);
      final per100 = _number(nutriments['energy-kcal_100g']);
      if (name == null || name.isEmpty || (perServing == null && per100 == null)) continue;
      matches.add(CalorieMatch(
        name: name,
        brand: (p['brands'] as String?)?.split(',').first.trim(),
        kcal: perServing ?? per100!,
        basis: perServing != null ? 'serving' : '100 g',
        source: source,
      ));
    }
    return matches;
  }

  static double? _number(Object? value) => switch (value) {
        num n when n > 0 => n.toDouble(),
        String s => double.tryParse(s),
        _ => null,
      };
}
