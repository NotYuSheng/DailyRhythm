/// A suggested change to past entries, to review and apply: a meal that
/// was a snack, a name that was two foods, a side logged on its own, a
/// food's brand.
class TidyFix {
  const TidyFix._(this.type, {this.mealId, this.name, this.date, this.kind, this.parts = const [], this.mainId, this.mainName, this.brand});

  /// Meal [mealId] ([name]) was a [kind].
  const TidyFix.kind({required int mealId, required String name, DateTime? date, required String kind})
    : this._(kindType, mealId: mealId, name: name, date: date, kind: kind);

  /// Meal [mealId] ([name]) was [parts]: the first is the meal, the rest its
  /// sides.
  const TidyFix.split({required int mealId, required String name, DateTime? date, required List<String> parts})
    : this._(splitType, mealId: mealId, name: name, date: date, parts: parts);

  /// Meal [mealId] ([name]) was a side of [mainId] ([mainName]).
  const TidyFix.side({required int mealId, required String name, DateTime? date, required int mainId, required String mainName})
    : this._(sideType, mealId: mealId, name: name, date: date, mainId: mainId, mainName: mainName);

  /// Food [name] is from [brand].
  const TidyFix.brand({required String name, required String brand}) : this._(brandType, name: name, brand: brand);

  static const kindType = 'kind', splitType = 'split', sideType = 'side', brandType = 'brand';

  /// Applied in this order: brands, then kinds, then splits and sides,
  /// so sides take their meal's kind.
  static const types = [brandType, kindType, splitType, sideType];

  static const titles = {
    kindType: 'Snacks, not meals',
    splitType: 'Two foods in one name',
    sideType: 'Sides logged on their own',
    brandType: 'Brands',
  };

  final String type;
  final int? mealId;
  final String? name;
  final DateTime? date;
  final String? kind;
  final List<String> parts;
  final int? mainId;
  final String? mainName;
  final String? brand;

  /// Identifies it, so a dismissed one isn't offered again.
  String get key => switch (type) {
    brandType => 'brand:${name?.toLowerCase()}',
    _ => '$type:$mealId',
  };

  /// What it changes, in a line.
  String get label => switch (type) {
    kindType => '$name → a $kind',
    splitType => '$name → ${parts.first} + ${parts.skip(1).join(' + ')}',
    sideType => '$name → a side of $mainName',
    _ => '$name → $brand',
  };

  Map<String, Object?> toJson() => {
    'type': type,
    'meal': ?mealId,
    'name': ?name,
    if (date != null) 'date': date!.toIso8601String().substring(0, 10),
    'kind': ?kind,
    if (parts.isNotEmpty) 'parts': parts,
    'of': ?mainId,
    'ofName': ?mainName,
    'brand': ?brand,
  };

  /// One from a suggestions file, or null when it doesn't make sense.
  static TidyFix? fromJson(Map<String, dynamic> j) {
    final name = j['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final date = switch (j['date']) {
      final String d => DateTime.tryParse(d),
      _ => null,
    };
    final meal = j['meal'];
    return switch (j['type']) {
      kindType when meal is int && (j['kind'] == 'meal' || j['kind'] == 'snack') => TidyFix.kind(mealId: meal, name: name, date: date, kind: j['kind'] as String),
      splitType when meal is int && j['parts'] is List && (j['parts'] as List).whereType<String>().length > 1 =>
        TidyFix.split(mealId: meal, name: name, date: date, parts: [for (final p in j['parts'] as List) if (p is String && p.trim().isNotEmpty) p.trim()]),
      sideType when meal is int && j['of'] is int => TidyFix.side(mealId: meal, name: name, date: date, mainId: j['of'] as int, mainName: (j['ofName'] as String?) ?? 'its meal'),
      brandType when j['brand'] is String && (j['brand'] as String).trim().isNotEmpty => TidyFix.brand(name: name, brand: (j['brand'] as String).trim()),
      _ => null,
    };
  }
}

/// An entry worth a look, with why: no price when the food usually has
/// one, a possible duplicate, a price far from usual.
class TidyFlag {
  const TidyFlag({required this.mealId, required this.name, required this.date, required this.reason});

  final int mealId;
  final String name;
  final DateTime date;
  final String reason;

  String get key => 'flag:$mealId:$reason';
}

/// What a check found.
class TidyReport {
  const TidyReport({this.fixes = const [], this.flags = const []});

  final List<TidyFix> fixes;
  final List<TidyFlag> flags;

  bool get isEmpty => fixes.isEmpty && flags.isEmpty;
}
