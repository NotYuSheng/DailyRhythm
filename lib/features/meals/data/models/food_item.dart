import 'dart:convert';

import '../../domain/diet_score.dart';

/// A canonical food: one name for its spelling variants, used for
/// autocomplete, the last price and (later) calories.
class FoodItem {
  final int? id;
  final String name;
  final List<String> aliases;
  final double? kcal; // per serving
  final String? kcalSource; // usda, sgfoodid, off, estimate, user
  final double? lastPrice;

  /// Health score categories the user set for this food ([DietScore]);
  /// null leaves it to the name.
  final List<String>? healthTags;

  FoodItem({this.id, required this.name, this.aliases = const [], this.kcal, this.kcalSource, this.lastPrice, this.healthTags});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'aliases': jsonEncode(aliases),
      'kcal': kcal,
      'kcal_source': kcalSource,
      'last_price': lastPrice,
      'health_tags': DietScore.encodeTags(healthTags),
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      aliases: (jsonDecode(map['aliases'] as String? ?? '[]') as List).cast<String>(),
      kcal: (map['kcal'] as num?)?.toDouble(),
      kcalSource: map['kcal_source'] as String?,
      lastPrice: (map['last_price'] as num?)?.toDouble(),
      healthTags: DietScore.decodeTags(map['health_tags']),
    );
  }
}
