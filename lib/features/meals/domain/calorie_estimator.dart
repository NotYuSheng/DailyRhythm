import '../../../shared/domain/name_matcher.dart';
import '../data/models/food_item.dart';

/// A common food's calories per typical serving, from the built-in table
/// (`assets/data/common_foods.json`). Estimates, not measurements.
class ReferenceFood {
  const ReferenceFood({required this.name, required this.kcal, this.aliases = const [], this.serving = ''});

  factory ReferenceFood.fromJson(Map<String, dynamic> json) => ReferenceFood(
        name: json['name'] as String,
        kcal: (json['kcal'] as num).toDouble(),
        aliases: [for (final a in json['aliases'] as List? ?? const []) a as String],
        serving: json['serving'] as String? ?? '',
      );

  final String name;
  final double kcal;
  final List<String> aliases;
  final String serving;
}

/// A suggested calories-per-serving for a food, and what it's based on.
class CalorieEstimate {
  const CalorieEstimate(this.kcal, this.basis);

  final double kcal;

  /// "from your Chicken rice", "like a typical Laksa".
  final String basis;
}

/// Suggests calories for a food that has none, offline: from the user's
/// own foods first, then the built-in table of common dishes. The user can
/// always change the value; it's saved as an estimate.
class CalorieEstimator {
  CalorieEstimator({required List<FoodItem> yourFoods, required this.reference})
      : yourFoods = [for (final f in yourFoods) if (f.kcal != null) f];

  final List<FoodItem> yourFoods;
  final List<ReferenceFood> reference;

  static final _sides = RegExp(r'\s+(?:with|w)\s+|\s+w/\s*|\s+\+\s+', caseSensitive: false);
  static const _filler = {'a', 'an', 'the', 'of', 'and', 'n', 'with', 'w', 'set', 'meal', 'plate', 'bowl', 'cup', 'small', 'large', 'big'};

  static String _key(String s) => s.toLowerCase().replaceAll(RegExp(r"[^\p{L}\p{N} ]", unicode: true), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  static Set<String> _words(String s) => {for (final w in _key(s).split(' ')) if (w.isNotEmpty && !_filler.contains(w)) w};

  CalorieEstimate? estimate(String name) {
    final full = _key(name);
    if (full.length < 2) return null;
    final main = _key(name.split(_sides).first);

    // 1. The same name (or alias): the whole thing, then the main dish.
    for (final key in {full, main}) {
      for (final f in yourFoods) {
        if (_key(f.name) == key || f.aliases.any((a) => _key(a) == key)) return CalorieEstimate(f.kcal!, 'from your ${f.name}');
      }
      for (final r in reference) {
        if (_key(r.name) == key || r.aliases.any((a) => _key(a) == key)) return CalorieEstimate(r.kcal, 'from a typical ${r.name}');
      }
    }

    // 2. A known name contained in this one ("Spicy laksa" has "laksa"):
    // the longest such name wins, the user's own foods on a tie.
    final words = _words(main);
    (int, CalorieEstimate)? best;
    void consider(String candidate, CalorieEstimate estimate, int bonus) {
      final need = _words(candidate);
      if (need.isEmpty || !words.containsAll(need)) return;
      final score = need.length * 2 + bonus;
      if (best == null || score > best!.$1) best = (score, estimate);
    }

    for (final f in yourFoods) {
      for (final n in [f.name, ...f.aliases]) {
        consider(n, CalorieEstimate(f.kcal!, 'like your ${f.name}'), 1);
      }
    }
    for (final r in reference) {
      for (final n in [r.name, ...r.aliases]) {
        consider(n, CalorieEstimate(r.kcal, 'like a typical ${r.name}'), 0);
      }
    }
    if (best != null) return best!.$2;

    // 3. A near spelling of a whole name ("chiken rice").
    if (main.length >= 6) {
      for (final f in yourFoods) {
        if (NameMatcher.editDistance(main, _key(f.name)) <= 2) return CalorieEstimate(f.kcal!, 'like your ${f.name}');
      }
      for (final r in reference) {
        if (NameMatcher.editDistance(main, _key(r.name)) <= 2) return CalorieEstimate(r.kcal, 'like a typical ${r.name}');
      }
    }
    return null;
  }
}
