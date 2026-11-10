/// Food and exercise names in one consistent style, Title Case, however
/// they were typed: "mixed rice" and "MIXED RICE" both become "Mixed Rice".
///
/// - Small joining words stay lower case unless first: "Rice with Egg".
/// - Brand-style words keep their capitals: "KFC", "McChicken", "BBQ".
/// - Words with digits are left as typed: "7-Eleven", "100plus".
/// - A shouted word longer than three letters is not an acronym: "NASI"
///   becomes "Nasi".
String tidyName(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return [for (final (i, w) in words.indexed) _word(w, first: i == 0)].join(' ');
}

const _small = {'a', 'an', 'and', 'as', 'at', 'by', 'for', 'from', 'in', 'of', 'on', 'or', 'the', 'to', 'with', 'w/', 'n', '&'};

String _word(String w, {required bool first}) {
  if (RegExp(r'\d').hasMatch(w)) return w;
  final letters = w.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.isEmpty) return w;
  final allCaps = letters == letters.toUpperCase();
  // Brands and acronyms: capitals after the first letter, as typed.
  if (allCaps ? letters.length <= 3 && letters.length > 1 : letters.substring(1) != letters.substring(1).toLowerCase()) return w;
  final lower = w.toLowerCase();
  if (!first && _small.contains(lower)) return lower;
  // Each hyphenated part capitalised: "Stir-Fry".
  return lower.split('-').map(_capital).join('-');
}

String _capital(String part) {
  final i = part.indexOf(RegExp('[a-z]'));
  return i < 0 ? part : '${part.substring(0, i)}${part[i].toUpperCase()}${part.substring(i + 1)}';
}
