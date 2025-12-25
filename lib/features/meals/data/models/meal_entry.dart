class MealEntry {
  final int? id;
  final DateTime date;
  final DateTime time;
  final String name;
  final int quantity;
  final double price;
  final int? calories;
  final List<String> tags;
  final String? notes;

  MealEntry({
    this.id,
    required this.date,
    required this.time,
    required this.name,
    this.quantity = 1,
    required this.price,
    this.calories,
    this.tags = const [],
    this.notes,
  });

  // Convert to Map for database
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
      price: map['price'] as double,
      calories: map['calories'] as int?,
      tags: map['tags'] != null && (map['tags'] as String).isNotEmpty
          ? (map['tags'] as String).split(',')
          : [],
      notes: map['notes'] as String?,
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
    );
  }
}
