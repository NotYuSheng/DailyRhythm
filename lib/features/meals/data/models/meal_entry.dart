/// Where a meal came from (stored in `meal_entries.food_source`).
class FoodSource {
  FoodSource._();

  static const takeout = 'takeout';
  static const fastFood = 'fast_food';
  static const homemade = 'homemade';
  static const free = 'free';
  static const restaurant = 'restaurant';
  static const foodCourt = 'food_court';
  static const delivery = 'delivery';

  static const all = [takeout, fastFood, homemade, free, restaurant, foodCourt, delivery];

  static const labels = {
    homemade: 'Home cooked',
    takeout: 'Takeout',
    foodCourt: 'Food court',
    restaurant: 'Restaurant',
    fastFood: 'Fast food',
    delivery: 'Delivery',
    free: 'Free',
  };
}

class MealEntry {
  final int? id;
  final DateTime date;
  final DateTime time;
  final String name;
  final int quantity;
  final double? price; // Total for the line; null when not recorded
  final int? calories;
  final List<String> tags;
  final String? notes;
  final String? foodSource; // one of FoodSource.all
  final int? foodItemId; // canonical food in food_items
  final String currency;
  final String? rawText; // original Daylio line, when imported
  final bool timeKnown; // false for imported meals, which have no time

  MealEntry({
    this.id,
    required this.date,
    required this.time,
    required this.name,
    this.quantity = 1,
    this.price,
    this.calories,
    this.tags = const [],
    this.notes,
    this.foodSource,
    this.foodItemId,
    this.currency = 'SGD',
    this.rawText,
    this.timeKnown = true,
  });

  // Convert to Map for database
  /// Calories for the line: as logged, or else the food's calories per
  /// serving times the quantity. Null when neither is known.
  double? caloriesWith(Map<int, double> foodKcal) =>
      calories?.toDouble() ?? switch (foodKcal[foodItemId]) {
        final kcal? => kcal * quantity,
        null => null,
      };

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'time': time.toIso8601String(),
      'name': name,
      'quantity': quantity,
      'price': price,
      'calories': calories,
      'tags': tags.join(','),
      'notes': notes,
      'food_source': foodSource,
      'food_item_id': foodItemId,
      'currency': currency,
      'raw_text': rawText,
      'time_known': timeKnown ? 1 : 0,
    };
  }

  // Create from Map (database)
  factory MealEntry.fromMap(Map<String, dynamic> map) {
    return MealEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      time: DateTime.parse(map['time'] as String),
      name: map['name'] as String,
      quantity: map['quantity'] as int? ?? 1,
      price: (map['price'] as num?)?.toDouble(),
      calories: map['calories'] as int?,
      tags: map['tags'] != null && (map['tags'] as String).isNotEmpty
          ? (map['tags'] as String).split(',')
          : [],
      notes: map['notes'] as String?,
      foodSource: map['food_source'] as String?,
      foodItemId: map['food_item_id'] as int?,
      currency: map['currency'] as String? ?? 'SGD',
      rawText: map['raw_text'] as String?,
      timeKnown: (map['time_known'] as int? ?? 1) != 0,
    );
  }

  // Copy with method for updates
  MealEntry copyWith({
    int? id,
    DateTime? date,
    DateTime? time,
    String? name,
    int? quantity,
    double? price,
    int? calories,
    List<String>? tags,
    String? notes,
    String? foodSource,
    int? foodItemId,
    String? currency,
    String? rawText,
    bool? timeKnown,
  }) {
    return MealEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      calories: calories ?? this.calories,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      foodSource: foodSource ?? this.foodSource,
      foodItemId: foodItemId ?? this.foodItemId,
      currency: currency ?? this.currency,
      rawText: rawText ?? this.rawText,
      timeKnown: timeKnown ?? this.timeKnown,
    );
  }
}
