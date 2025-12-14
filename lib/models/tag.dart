class Tag {
  final int? id;
  final String name;
  final String emoji;
  final String category;
  final String? color; // Store as hex string for future use
  final int? sortOrder;

  Tag({
    this.id,
    required this.name,
    required this.emoji,
    required this.category,
    this.color,
    this.sortOrder,
  });

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'category': category,
      'color': color,
      'sort_order': sortOrder,
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
      sortOrder: map['sort_order'] as int?,
    );
  }

  // Copy with method for updates
  Tag copyWith({
    int? id,
    String? name,
    String? emoji,
    String? category,
    String? color,
    int? sortOrder,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      category: category ?? this.category,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  // Display label with emoji
  String get displayLabel => '$emoji $name';
}

class TagCategory {
  final int? id;
  final String name;
  final String? color; // Store as hex string
  final int? sortOrder;

  TagCategory({
    this.id,
    required this.name,
    this.color,
    this.sortOrder,
  });

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'sort_order': sortOrder,
    };
  }

  // Create from Map (database)
  factory TagCategory.fromMap(Map<String, dynamic> map) {
    return TagCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as String?,
      sortOrder: map['sort_order'] as int?,
    );
  }

  // Copy with method for updates
  TagCategory copyWith({
    int? id,
    String? name,
    String? color,
    int? sortOrder,
  }) {
    return TagCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
