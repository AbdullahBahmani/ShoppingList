import 'package:flutter/foundation.dart';

/// A single entry on a shopping list.
@immutable
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.category = Category.other,
    this.isPurchased = false,
  });

  final String id;
  final String name;
  final int quantity;
  final Category category;
  final bool isPurchased;

  ShoppingItem copyWith({
    String? name,
    int? quantity,
    Category? category,
    bool? isPurchased,
  }) {
    return ShoppingItem(
      id: id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      isPurchased: isPurchased ?? this.isPurchased,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'category': category.name,
    'isPurchased': isPurchased,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as int? ?? 1,
      category: CategoryX.fromName(json['category'] as String?),
      isPurchased: json['isPurchased'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingItem &&
          other.id == id &&
          other.name == name &&
          other.quantity == quantity &&
          other.category == category &&
          other.isPurchased == isPurchased;

  @override
  int get hashCode =>
      Object.hash(id, name, quantity, category, isPurchased);
}

/// Groups items so a list stays organised while shopping.
enum Category {
  produce('Produce'),
  bakery('Bakery'),
  dairy('Dairy'),
  meat('Meat & Seafood'),
  pantry('Pantry'),
  frozen('Frozen'),
  beverages('Beverages'),
  household('Household'),
  other('Other');

  const Category(this.label);

  final String label;

  /// Material icon key resolved in the widget layer, keeping the model
  /// free of Flutter icon imports.
  String get iconKey => name;
}

/// Safe enum parsing shared by both the item and list decoders.
extension CategoryX on Category {
  static Category fromName(String? name) {
    return Category.values.firstWhere(
      (c) => c.name == name,
      orElse: () => Category.other,
    );
  }
}
