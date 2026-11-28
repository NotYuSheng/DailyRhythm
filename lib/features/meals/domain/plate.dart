import 'dart:convert';

import 'diet_score.dart';

/// A change to a food's usual plate: one of the sides it comes with
/// swapped for another, or left out.
class PlateChange {
  const PlateChange(this.side, {this.swapFor});

  /// The usual side ("Fries").
  final String side;

  /// What came instead ("Corn"); null when it was left out.
  final String? swapFor;

  bool get leftOut => swapFor == null;

  String get label => swapFor == null ? 'no $side' : '$swapFor instead of $side';

  Map<String, String> toJson() => {'side': side, 'for': ?swapFor};

  @override
  bool operator ==(Object other) => other is PlateChange && other.side == side && other.swapFor == swapFor;

  @override
  int get hashCode => Object.hash(side, swapFor);
}

/// A food as it usually comes ("Chicken chop" with fries and coleslaw), and
/// a meal's changes to it. A meal with no changes is the plate as usual,
/// which its food's calories and health already describe, so meals logged
/// before a food had sides need nothing.
class Plate {
  Plate._();

  static List<String> decodeSides(Object? stored) =>
      stored is String && stored.isNotEmpty ? [for (final s in (jsonDecode(stored) as List).cast<String>()) if (s.trim().isNotEmpty) s.trim()] : const [];

  static String? encodeSides(List<String> sides) => sides.isEmpty ? null : jsonEncode(sides);

  static List<PlateChange> decodeChanges(Object? stored) {
    if (stored is! String || stored.isEmpty) return const [];
    return [
      for (final c in (jsonDecode(stored) as List).cast<Map<String, dynamic>>())
        if (c['side'] case final String side) PlateChange(side, swapFor: c['for'] as String?),
    ];
  }

  static String? encodeChanges(List<PlateChange> changes) => changes.isEmpty ? null : jsonEncode([for (final c in changes) c.toJson()]);

  /// "Fries, coleslaw" typed in a box, as a list of sides.
  static List<String> parseSides(String typed) {
    final seen = <String>{};
    return [
      for (final s in typed.split(RegExp(r'[,;\n]')))
        if (s.trim() case final side when side.isNotEmpty && seen.add(side.toLowerCase())) side,
    ];
  }

  /// One serving's change in calories, from each side's calories
  /// ([kcalOf], null when unknown). A swap whose either side is unknown
  /// changes nothing.
  static double kcalChange(List<PlateChange> changes, double? Function(String name) kcalOf) {
    var change = 0.0;
    for (final c in changes) {
      final usual = kcalOf(c.side);
      if (usual == null) continue;
      if (c.swapFor case final other?) {
        final instead = kcalOf(other);
        if (instead != null) change += instead - usual;
      } else {
        change -= usual;
      }
    }
    return change;
  }

  /// The health categories of a plate as usual: the food's name and its
  /// sides'. [tagsOf] is a food's own categories, or what its name points to.
  static Set<String> usualTags(String name, List<String> sides, Set<String> Function(String name) tagsOf) =>
      {...DietScore.detect(name), for (final s in sides) ...tagsOf(s)};

  /// The categories of a plate with [changes], from its usual ones
  /// ([usual]): a left-out side takes away what only it brought, and a
  /// swapped-in one adds its own.
  static List<String> changedTags({
    required String name,
    required Set<String> usual,
    required List<String> sides,
    required List<PlateChange> changes,
    required Set<String> Function(String name) tagsOf,
  }) {
    final changed = {for (final c in changes) c.side.toLowerCase()};
    final kept = {...DietScore.detect(name), for (final s in sides) if (!changed.contains(s.toLowerCase())) ...tagsOf(s)};
    final tags = {...usual};
    for (final c in changes) {
      tags.removeAll(tagsOf(c.side).difference(kept));
    }
    for (final c in changes) {
      if (c.swapFor case final other?) tags.addAll(tagsOf(other));
    }
    return [for (final cat in DietScore.categories) if (tags.contains(cat.key)) cat.key];
  }
}
