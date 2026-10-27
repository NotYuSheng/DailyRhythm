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
  CalorieEstimator({required List<FoodItem> yourFoods, required List<ReferenceFood> reference})
      : _candidates = [
          // Names, aliases, keys and word sets worked out once, not per keystroke.
          for (final f in yourFoods)
            if (f.kcal != null)
              for (final (i, n) in [f.name, ...f.aliases].indexed)
                _Candidate(_key(n), _words(n), CalorieEstimate(f.kcal!, 'from your ${f.name}'), CalorieEstimate(f.kcal!, 'like your ${f.name}'), mine: true, isName: i == 0),
          for (final r in reference)
            for (final (i, n) in [r.name, ...r.aliases].indexed)
              _Candidate(_key(n), _words(n), CalorieEstimate(r.kcal, 'from a typical ${r.name}'), CalorieEstimate(r.kcal, 'like a typical ${r.name}'), mine: false, isName: i == 0),
        ];

  final List<_Candidate> _candidates;
  String? _lastQuery;
  CalorieEstimate? _lastAnswer;

  static final _sides = RegExp(r'\s+(?:with|w)\s+|\s+w/\s*|\s+\+\s+', caseSensitive: false);
  static const _filler = {'a', 'an', 'the', 'of', 'and', 'n', 'with', 'w', 'set', 'meal', 'plate', 'bowl', 'cup', 'small', 'large', 'big'};

  static String _key(String s) => s.toLowerCase().replaceAll(RegExp(r"[^\p{L}\p{N} ]", unicode: true), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  static Set<String> _words(String s) => {for (final w in _key(s).split(' ')) if (w.isNotEmpty && !_filler.contains(w)) w};

  CalorieEstimate? estimate(String name) {
    // Screens rebuild often; work each name out once.
    if (name == _lastQuery) return _lastAnswer;
    _lastQuery = name;
    return _lastAnswer = _estimate(name);
  }

  CalorieEstimate? _estimate(String name) {
    final full = _key(name);
    if (full.length < 2) return null;
    final main = _key(name.split(_sides).first);
    // The user's own foods come before the table at every step.
    final ordered = [..._candidates.where((c) => c.mine), ..._candidates.where((c) => !c.mine)];

    // 1. The same name (or alias): the whole thing, then the main dish.
    for (final key in {full, main}) {
      for (final c in ordered) {
        if (c.key == key) return c.same;
      }
    }

    // 2. A known name contained in this one ("Spicy laksa" has "laksa"):
    // the longest such name wins, the user's own foods on a tie.
    final words = _words(main);
    _Candidate? best;
    int score(_Candidate c) => c.words.length * 2 + (c.mine ? 1 : 0);
    for (final c in ordered) {
      if (c.words.isEmpty || !words.containsAll(c.words)) continue;
      if (best == null || score(c) > score(best)) best = c;
    }
    if (best != null) return best.like;

    // 3. A near spelling of a whole name ("chiken rice"). Stricter than
    // "Did you mean", as a wrong match saves a wrong number: short names
    // differ by a letter ("Kopi o", "Kopi c"), so none below eight
    // letters, one edit from eight and two from twelve.
    if (main.length >= 8) {
      final allowed = main.length >= 12 ? 2 : 1;
      for (final c in ordered) {
        if (c.isName && (c.key.length - main.length).abs() <= allowed && NameMatcher.editDistance(main, c.key) <= allowed) return c.like;
      }
    }
    return null;
  }
}

class _Candidate {
  const _Candidate(this.key, this.words, this.same, this.like, {required this.mine, required this.isName});

  final String key;
  final Set<String> words;
  final CalorieEstimate same;
  final CalorieEstimate like;
  final bool mine;
  final bool isName;
}
