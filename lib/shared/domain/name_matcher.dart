import 'dart:math' as math;

/// A catalog item and how often it has been logged.
class Choice<T> {
  const Choice(this.item, this.uses);

  final T item;
  final int uses;
}

/// Matches typed text against named catalog items (foods, exercises), in
/// memory, so suggestions update on every keystroke without a query.
abstract class NameMatcher<T> {
  NameMatcher(this.choices);

  final List<Choice<T>> choices;

  String nameOf(T item);
  List<String> aliasesOf(T item);

  static String _key(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Items for [query]: names starting with it, then a word starting with
  /// it, then containing it (or an alias that does), each by most logged.
  List<Choice<T>> suggest(String query, {int limit = 6}) {
    final q = _key(query);
    if (q.isEmpty) return const [];
    int? rank(Choice<T> c) {
      final name = _key(nameOf(c.item));
      if (name == q) return null; // already typed in full
      if (name.startsWith(q)) return 0;
      if (name.split(' ').any((w) => w.startsWith(q))) return 1;
      if (name.contains(q) || aliasesOf(c.item).any((a) => _key(a).contains(q))) return 2;
      return 3;
    }

    final ranked = [
      for (final c in choices)
        if (rank(c) case final r? when r < 3) (r, c),
    ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : b.$2.uses.compareTo(a.$2.uses));
    return [for (final (_, c) in ranked.take(limit)) c];
  }

  /// The item [text] names exactly, by name or alias.
  Choice<T>? exact(String text) {
    final q = _key(text);
    for (final c in choices) {
      if (_key(nameOf(c.item)) == q) return c;
    }
    for (final c in choices) {
      if (aliasesOf(c.item).any((a) => _key(a) == q)) return c;
    }
    return null;
  }

  /// The agreed name to offer instead of [text]: the item whose alias it
  /// is, or a close spelling of a logged item. Null when [text] already is
  /// an item's name, or nothing is close.
  Choice<T>? didYouMean(String text) {
    final q = _key(text);
    if (q.length < 3) return null;
    final match = exact(text);
    if (match != null) return _key(nameOf(match.item)) == q ? null : match;

    // One edit for short names, two for longer ones; most logged wins ties.
    final allowed = q.length >= 8 ? 2 : 1;
    Choice<T>? best;
    var bestDistance = allowed + 1;
    for (final c in choices) {
      final name = _key(nameOf(c.item));
      if ((name.length - q.length).abs() > allowed) continue;
      final d = editDistance(q, name);
      if (d < bestDistance || (d == bestDistance && best != null && c.uses > best.uses)) {
        best = c;
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
