import 'dart:math' as math;

/// How healthy a day's food was, 1 (less healthy) to 5 (healthy), from the
/// names of what was eaten. Rules, not a nutrition analysis: rough, and
/// each score says what moved it.
///
/// A meal starts at 3, a typical plate. Fried food, fast food, sweets and
/// sugary drinks, and processed food lower it; vegetables, steamed food and
/// clear soups, fish and lean protein, and fruit raise it. A day is the
/// meals' average, weighted by calories so a snack counts less than a plate.
class DietScore {
  DietScore._();

  static const levels = ['1 · Less healthy', '2', '3', '4', '5 · Healthy'];

  static final _rules = <(String, RegExp, double)>[
    ('fried', _words(r'fried|goreng|crispy|katsu|karaage|tempura|nuggets?|fries|chips|wings?|popcorn chicken|fritters?|carrot cake|onion rings|cheese rings|hash ?browns?|curry puffs?|old chang kee|old chung kee|prata|murtabak|you tiao|ngoh hiang'), -1),
    ('fast food', _words(r"mcdonald'?s?|mc ?spicy|mc ?chicken|mc ?wings|big mac|filet o fish|fillet o fish|kfc|popeyes|burger king|whopper|texas chicken|jollibee|long john|pizza hut|domino'?s?|subway|burgers?|pizza|big breakfast|breakfast deluxe|mc ?muffins?|mc ?wrap|mc ?griddles?"), -1),
    ('rich', _words(r'nasi lemak|laksa|char kway teow|char kuey teow|hokkien mee|carbonara|cream sauce|cheesy|cheese|butter|mayo'), -0.5),
    ('sweet', _words(r'(?<!carrot |fish )cakes?|cookies?|donuts?|doughnuts?|ice cream|mcflurry|gelato|waffles?|chocolate|bubble tea|milk tea|boba|coke|soft drink|soda|dessert|kueh|cream puffs?|tarts?|croissants?|brownies?|candy|sweets'), -1),
    ('processed', _words(r'maggi|instant noodles?|shin ramen|cup noodles?|sausages?|hot ?dogs?|luncheon|spam|ham|bacon'), -0.5),
    ('vegetables', _words(r'veg|vegetables?|salad|brocc?oli|brocolli|spinach|cabbage|kai ?lan|bean ?sprouts?|greens|kangkong|chye sim|tomato(es)?|cucumber|carrots?(?! cake)'), 1),
    ('steamed or soup', _words(r'steam(ed)?|soup|porridge|congee|yong tau foo|thunder tea|clear broth|boiled'), 1),
    ('fish or lean protein', _words(r'fish(?! (and|&) chips)|salmon|sashimi|tofu|chicken breast|grilled|eggs?|tuna|prawns?|lean'), 0.5),
    ('fruit', _words(r'fruits?|apples?|bananas?|oranges?|watermelon|papaya|grapes|berries|kiwi|pear|mango|oats|yogh?urt'), 1),
  ];

  static RegExp _words(String alternatives) => RegExp('\\b(?:$alternatives)\\b', caseSensitive: false);

  static final _notFood = RegExp(r'\b(?:creatine|protein(?: shake| powder)?|supplements?|vitamins?|fish oil|water)$|\b(?:creatine|protein shake|supplements?|vitamins?|fish oil)\b', caseSensitive: false);

  /// One food's score and what moved it, or null for supplements and water.
  static ({double score, List<String> reasons})? forFood(String name) {
    if (_notFood.hasMatch(name)) return null;
    var score = 3.0;
    final reasons = <String>[];
    for (final (reason, pattern, delta) in _rules) {
      if (pattern.hasMatch(name)) {
        score += delta;
        reasons.add(reason);
      }
    }
    return (score: score.clamp(1, 5).toDouble(), reasons: reasons);
  }

  /// "Health 2/5 · fried, fast food", or null for what isn't scored.
  static String? describe(String name) {
    final food = forFood(name);
    if (food == null || name.trim().isEmpty) return null;
    final score = food.score == food.score.roundToDouble() ? '${food.score.round()}' : food.score.toStringAsFixed(1);
    return 'Health $score/5 · ${food.reasons.isEmpty ? 'a typical plate' : food.reasons.join(', ')}';
  }

  /// A day's average from (name, kcal) pairs; meals without calories weigh
  /// as a typical meal. Null when nothing scored.
  static double? forDay(Iterable<(String, double?)> meals) {
    var total = 0.0, weight = 0.0;
    for (final (name, kcal) in meals) {
      final food = forFood(name);
      if (food == null) continue;
      final w = math.max(50.0, kcal ?? 500);
      total += food.score * w;
      weight += w;
    }
    return weight == 0 ? null : total / weight;
  }

  /// 1–5, rounded, or null.
  static int? levelFor(double? score) => score?.round().clamp(1, 5);
}
