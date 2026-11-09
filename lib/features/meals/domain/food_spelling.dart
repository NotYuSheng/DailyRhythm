import '../../../shared/domain/name_matcher.dart';

/// Spelling help for food names, word by word, so a new dish gets "Did
/// you mean …?" too: "chiken rice" → "chicken rice" even when it was never
/// logged. The words come from the user's foods (counted most) and the
/// bundled food lists.
class FoodSpelling {
  FoodSpelling(Map<String, int> counts) : _counts = counts;

  /// No words: corrects nothing.
  FoodSpelling.empty() : _counts = const {};

  final Map<String, int> _counts;

  static final _word = RegExp(r"[a-z][a-z'’]*", caseSensitive: false);

  /// Counts the words in [names], each name's words once, [weight] each.
  static Map<String, int> countWords(Iterable<String> names, {int weight = 1}) {
    final counts = <String, int>{};
    for (final name in names) {
      for (final w in {for (final m in _word.allMatches(name.toLowerCase())) m.group(0)!}) {
        if (w.length >= 2) counts[w] = (counts[w] ?? 0) + weight;
      }
    }
    return counts;
  }

  /// These words added, counted on top of the ones already known.
  FoodSpelling withWords(Map<String, int> more) {
    final counts = {..._counts};
    more.forEach((w, n) => counts[w] = (counts[w] ?? 0) + n);
    return FoodSpelling(counts);
  }

  bool knows(String word) => _counts.containsKey(word.toLowerCase());

  /// [text] with misspelt words corrected, or null when nothing changes.
  /// While [typing], the last word may be unfinished, so it's left alone.
  String? correct(String text, {bool typing = false}) {
    final key = '$typing|$text';
    if (key == _lastKey) return _lastAnswer;
    _lastKey = key;
    return _lastAnswer = _correct(text, typing);
  }

  String? _lastKey;
  String? _lastAnswer;

  String? _correct(String text, bool typing) {
    if (_counts.isEmpty) return null;
    final matches = _word.allMatches(text).toList();
    if (typing && matches.isNotEmpty && matches.last.end == text.length) matches.removeLast();
    var out = text;
    var changed = false;
    // Backwards, so earlier offsets stay right as words change length.
    for (final m in matches.reversed) {
      final word = m.group(0)!;
      final fixed = _fix(word.toLowerCase());
      if (fixed == null) continue;
      out = out.replaceRange(m.start, m.end, _sameCase(word, fixed));
      changed = true;
    }
    return changed ? out : null;
  }

  /// The known word [word] most likely meant, or null if it's known, too
  /// short to guess, or nothing is close. One edit for short words, two
  /// for long ones; the more common word wins a tie.
  String? _fix(String word) {
    if (word.length < 5 || _counts.containsKey(word)) return null;
    final allowed = word.length >= 8 ? 2 : 1;
    String? best;
    var bestDistance = allowed + 1;
    var bestCount = 0;
    for (final MapEntry(key: w, value: n) in _counts.entries) {
      if ((w.length - word.length).abs() > allowed || w.length < 3) continue;
      final d = NameMatcher.editDistance(word, w);
      if (d < bestDistance || (d == bestDistance && n > bestCount)) {
        best = w;
        bestDistance = d;
        bestCount = n;
      }
    }
    return bestDistance <= allowed ? best : null;
  }

  static String _sameCase(String typed, String fixed) {
    if (typed == typed.toUpperCase() && typed.length > 1) return fixed.toUpperCase();
    if (typed[0] == typed[0].toUpperCase()) return '${fixed[0].toUpperCase()}${fixed.substring(1)}';
    return fixed;
  }
}
