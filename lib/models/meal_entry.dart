class MealEntry {
  final int? id;
  final DateTime date;
  final DateTime time;
  final String name;
  final double price;
  final List<String> tags;
  final String? notes;

  MealEntry({
    this.id,
    required this.date,
    required this.time,
    required this.name,
    required this.price,
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
      'price': price,
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
      price: map['price'] as double,
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
    double? price,
    List<String>? tags,
    String? notes,
  }) {
    return MealEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      name: name ?? this.name,
      price: price ?? this.price,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
    );
  }
}
