import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/shopping_item.dart';
import '../models/shopping_list.dart';

/// Local persistence for all lists.
///
/// Handles migration from the original single-list storage format so
/// existing users do not lose data.
class ListStorage {
  static const _listsKey = 'shopping_lists_v2';
  static const _activeListKey = 'active_list_id';
  static const _legacyItemsKey = 'shopping_list_items';

  Future<List<ShoppingList>> loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_listsKey);

    if (raw != null) {
      final decoded = _decodeLists(raw);
      if (decoded != null) return decoded;
    }

    // No v2 payload: try to rescue a legacy single list.
    final migrated = await _migrateLegacy(prefs);
    if (migrated.isNotEmpty) {
      await saveLists(migrated);
      return migrated;
    }

    return [];
  }

  List<ShoppingList>? _decodeLists(String raw) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => ShoppingList.fromJson(e as Map<String, dynamic>))
          .toList();
    } on FormatException {
      return null;
    } on TypeError {
      // Shape mismatch from a partial write: fall back to migration path.
      return null;
    }
  }

  Future<List<ShoppingList>> _migrateLegacy(SharedPreferences prefs) async {
    final legacyRaw = prefs.getString(_legacyItemsKey);
    if (legacyRaw == null) return const [];

    try {
      final items = (jsonDecode(legacyRaw) as List<dynamic>)
          .map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
          .toList();

      if (items.isEmpty) return const [];

      final now = DateTime.now();
      return [
        ShoppingList(
          id: 'migrated-${now.microsecondsSinceEpoch}',
          name: 'My List',
          createdAt: now,
          updatedAt: now,
          items: items,
        ),
      ];
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  Future<void> saveLists(List<ShoppingList> lists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _listsKey,
      jsonEncode(lists.map((l) => l.toJson()).toList()),
    );
  }

  Future<String?> loadActiveListId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeListKey);
  }

  Future<void> saveActiveListId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_activeListKey);
    } else {
      await prefs.setString(_activeListKey, id);
    }
  }
}
