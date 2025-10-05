class Tag {
  final int? id;
  final String name;
  final String emoji;
  final String category;
  final String? color; // Store as hex string for future use

  Tag({
    this.id,
    required this.name,
    required this.emoji,
    required this.category,
    this.color,
  });

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'category': category,
      'color': color,
    };
  }

  // Create from Map (database)
  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as int?,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      category: map['category'] as String,
      color: map['color'] as String?,
    );
  }

  // Copy with method for updates
  Tag copyWith({
    int? id,
    String? name,
    String? emoji,
    String? category,
    String? color,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      category: category ?? this.category,
      color: color ?? this.color,
    );
  }

  // Display label with emoji
  String get displayLabel => '$emoji $name';
}

class TagCategory {
  final int? id;
  final String name;
  final String? color; // Store as hex string

  TagCategory({
    this.id,
    required this.name,
    this.color,
  });

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }

  // Create from Map (database)
  factory TagCategory.fromMap(Map<String, dynamic> map) {
    return TagCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as String?,
    );
  }

  // Copy with method for updates
  TagCategory copyWith({
    int? id,
    String? name,
    String? color,
  }) {
    return TagCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}
