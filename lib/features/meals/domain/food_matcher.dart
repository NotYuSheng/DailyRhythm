import 'dart:math' as math;

import '../data/models/food_item.dart';

/// A food and how often it has been logged.
class FoodChoice {
  const FoodChoice(this.item, this.uses);

  final FoodItem item;
  final int uses;
}

/// Matches typed text against the user's foods, in memory, so suggestions
/// update on every keystroke without a query.
class FoodMatcher {
  FoodMatcher(this.foods);

  final List<FoodChoice> foods;

  static String _key(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Foods for [query]: names starting with it, then a word starting with
  /// it, then containing it (or an alias that does), each by most logged.
  List<FoodChoice> suggest(String query, {int limit = 6}) {
    final q = _key(query);
    if (q.isEmpty) return const [];
    int? rank(FoodChoice f) {
      final name = _key(f.item.name);
      if (name == q) return null; // already typed in full
      if (name.startsWith(q)) return 0;
      if (name.split(' ').any((w) => w.startsWith(q))) return 1;
      if (name.contains(q) || f.item.aliases.any((a) => _key(a).contains(q))) return 2;
      return 3;
    }

    final ranked = [
      for (final f in foods)
        if (rank(f) case final r? when r < 3) (r, f),
    ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : b.$2.uses.compareTo(a.$2.uses));
    return [for (final (_, f) in ranked.take(limit)) f];
  }

  /// The food [text] names exactly, by name or alias.
  FoodChoice? exact(String text) {
    final q = _key(text);
    for (final f in foods) {
      if (_key(f.item.name) == q) return f;
    }
    for (final f in foods) {
      if (f.item.aliases.any((a) => _key(a) == q)) return f;
    }
    return null;
  }

  /// The agreed name to offer instead of [text]: the food whose alias it
  /// is, or a close spelling of a logged food. Null when [text] already is
  /// a food's name, or nothing is close.
  FoodChoice? didYouMean(String text) {
    final q = _key(text);
    if (q.length < 3) return null;
    final match = exact(text);
    if (match != null) return _key(match.item.name) == q ? null : match;

    // One edit for short names, two for longer ones; most logged wins ties.
    final allowed = q.length >= 8 ? 2 : 1;
    FoodChoice? best;
    var bestDistance = allowed + 1;
    for (final f in foods) {
      final name = _key(f.item.name);
      if ((name.length - q.length).abs() > allowed) continue;
      final d = editDistance(q, name);
      if (d < bestDistance || (d == bestDistance && best != null && f.uses > best.uses)) {
        best = f;
        bestDistance = d;
      }
    }
    return bestDistance <= allowed ? best : null;
  }

  /// Levenshtein distance.
  static int editDistance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = [i, ...List<int>.filled(b.length, 0)];
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = math.min(math.min(current[j - 1] + 1, previous[j] + 1), previous[j - 1] + cost);
      }
      previous = current;
    }
    return previous[b.length];
  }
}
