import 'package:flutter/foundation.dart' hide Category;

import 'shopping_item.dart';

/// A named, dated collection of items. Lists are the top-level unit:
/// the app holds many of them and the user switches between them.
@immutable
class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.isArchived = false,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ShoppingItem> items;

  /// Archived lists are read-only snapshots kept for reference.
  final bool isArchived;

  int get totalItems => items.length;
  int get purchasedCount => items.where((i) => i.isPurchased).length;
  int get activeCount => items.length - purchasedCount;

  /// 0.0 to 1.0. Used for the progress indicator on list cards.
  double get progress => items.isEmpty ? 0 : purchasedCount / items.length;

  bool get isComplete => items.isNotEmpty && purchasedCount == items.length;

  /// Most frequent category, used as the card's visual anchor.
  Category get dominantCategory {
    if (items.isEmpty) return Category.other;

    final counts = <Category, int>{};
    for (final item in items) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }

    return counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  ShoppingList copyWith({
    String? name,
    DateTime? updatedAt,
    List<ShoppingItem>? items,
    bool? isArchived,
  }) {
    return ShoppingList(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isArchived': isArchived,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final fallback = DateTime.now();

    return ShoppingList(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? fallback,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? fallback,
      isArchived: json['isArchived'] as bool? ?? false,
      items: rawItems
          .map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
