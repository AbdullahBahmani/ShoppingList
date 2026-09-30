import 'package:flutter/foundation.dart' hide Category;
import 'package:uuid/uuid.dart';

import '../data/list_storage.dart';
import '../models/shopping_item.dart';
import '../models/shopping_list.dart';
import '../services/share_service.dart';

enum ItemFilter { all, toBuy, inCart }

/// Owns every list, the active selection, and all mutations.
class ShoppingListsProvider extends ChangeNotifier {
  ShoppingListsProvider({ListStorage? storage, String Function()? idFactory})
    : _storage = storage ?? ListStorage(),
      _idFactory = idFactory ?? _defaultId;

  static const _uuid = Uuid();
  static String _defaultId() => _uuid.v4();

  final ListStorage _storage;
  final String Function() _idFactory;

  final List<ShoppingList> _lists = [];
  String? _activeListId;
  bool _isLoading = true;
  ItemFilter _itemFilter = ItemFilter.all;
  Category? _categoryFilter;

  bool get isLoading => _isLoading;
  ItemFilter get itemFilter => _itemFilter;
  Category? get categoryFilter => _categoryFilter;

  /// Active (non-archived) lists, newest first.
  List<ShoppingList> get activeLists {
    final list = _lists.where((l) => !l.isArchived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Archived lists, newest first.
  List<ShoppingList> get archivedLists {
    final list = _lists.where((l) => l.isArchived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  ShoppingList? get activeList {
    if (_lists.isEmpty) return null;

    final match = _lists.where((l) => l.id == _activeListId);
    if (match.isNotEmpty) return match.first;

    // Fall back to the newest active list if the pointer went stale.
    final candidates = activeLists;
    return candidates.isEmpty ? _lists.first : candidates.first;
  }

  String? get activeListId => activeList?.id;

  /// Items of the active list after applying filters.
  List<ShoppingItem> get visibleItems {
    final items = activeList?.items ?? const <ShoppingItem>[];

    final byState = items.where((item) {
      return switch (_itemFilter) {
        ItemFilter.all => true,
        ItemFilter.toBuy => !item.isPurchased,
        ItemFilter.inCart => item.isPurchased,
      };
    });

    final byCategory = byState.where(
      (item) => _categoryFilter == null || item.category == _categoryFilter,
    );

    final sorted = byCategory.toList()
      ..sort((a, b) {
        if (a.isPurchased != b.isPurchased) return a.isPurchased ? 1 : -1;
        return a.category.index.compareTo(b.category.index);
      });

    return sorted;
  }

  int get activeItemCount => activeList?.activeCount ?? 0;
  int get inCartCount => activeList?.purchasedCount ?? 0;
  double get progress => activeList?.progress ?? 0;

  Future<void> load() async {
    _lists
      ..clear()
      ..addAll(await _storage.loadLists());

    final savedId = await _storage.loadActiveListId();
    _activeListId = _lists.any((l) => l.id == savedId)
        ? savedId
        : _lists.where((l) => !l.isArchived).firstOrNull?.id;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _persist() => _storage.saveLists(_lists);

  // ---------------------------------------------------------------- lists

  Future<ShoppingList> createList(String name, {List<ShoppingItem>? items}) async {
    final now = DateTime.now();
    final list = ShoppingList(
      id: _idFactory(),
      name: name.trim().isEmpty ? 'Untitled list' : name.trim(),
      createdAt: now,
      updatedAt: now,
      items: items ?? const [],
    );

    _lists.add(list);
    _activeListId = list.id;
    _resetFilters();

    notifyListeners();
    await _persist();
    // Persist the selection too, otherwise a new list would not be restored
    // as active after a restart.
    await _storage.saveActiveListId(list.id);
    return list;
  }

  Future<void> renameList(String id, String name) async {
    final index = _indexOf(id);
    if (index == -1) return;

    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    _lists[index] = _lists[index].copyWith(
      name: trimmed,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
    await _persist();
  }

  Future<void> selectList(String id) async {
    if (_activeListId == id) return;

    _activeListId = id;
    _resetFilters();

    notifyListeners();
    await _storage.saveActiveListId(id);
  }

  /// Archives a list. Archived lists are read-only and hidden from the
  /// main screen until restored.
  Future<void> archiveList(String id) async {
    final index = _indexOf(id);
    if (index == -1) return;

    _lists[index] = _lists[index].copyWith(
      isArchived: true,
      updatedAt: DateTime.now(),
    );

    if (_activeListId == id) {
      _activeListId = activeLists.firstOrNull?.id;
      await _storage.saveActiveListId(_activeListId);
    }

    notifyListeners();
    await _persist();
  }

  Future<void> restoreList(String id) async {
    final index = _indexOf(id);
    if (index == -1) return;

    _lists[index] = _lists[index].copyWith(
      isArchived: false,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
    await _persist();
  }

  /// Permanently removes a list. Only reachable from the archive screen.
  Future<void> deleteList(String id) async {
    _lists.removeWhere((l) => l.id == id);

    if (_activeListId == id) {
      _activeListId = activeLists.firstOrNull?.id;
      await _storage.saveActiveListId(_activeListId);
    }

    notifyListeners();
    await _persist();
  }

  /// Copies an archived list into a fresh active one.
  Future<ShoppingList?> duplicateList(String id) async {
    final index = _indexOf(id);
    if (index == -1) return null;

    final source = _lists[index];
    return createList(
      source.name,
      items: source.items
          .map((i) => ShoppingItem(id: _idFactory(), name: i.name,
              quantity: i.quantity, category: i.category))
          .toList(),
    );
  }

  // ---------------------------------------------------------------- items

  Future<void> addItem({
    required String name,
    int quantity = 1,
    Category category = Category.other,
  }) async {
    final index = _activeListIndex;
    if (index == -1) return;

    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final items = [
      ..._lists[index].items,
      ShoppingItem(
        id: _idFactory(),
        name: trimmed,
        quantity: quantity < 1 ? 1 : quantity,
        category: category,
      ),
    ];

    _lists[index] = _lists[index].copyWith(
      items: items,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
    await _persist();
  }

  Future<void> togglePurchased(String itemId) async {
    await _mutateItems((items) {
      return [
        for (final item in items)
          if (item.id == itemId)
            item.copyWith(isPurchased: !item.isPurchased)
          else
            item,
      ];
    });
  }

  Future<void> setPurchased(String itemId, bool purchased) async {
    await _mutateItems((items) {
      return [
        for (final item in items)
          if (item.id == itemId)
            item.copyWith(isPurchased: purchased)
          else
            item,
      ];
    });
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    await _mutateItems((items) {
      return [
        for (final item in items)
          if (item.id == itemId)
            item.copyWith(quantity: quantity < 1 ? 1 : quantity)
          else
            item,
      ];
    });
  }

  Future<void> removeItem(String itemId) async {
    await _mutateItems(
      (items) => items.where((i) => i.id != itemId).toList(),
    );
  }

  Future<void> clearPurchasedItems() async {
    await _mutateItems(
      (items) => items.where((i) => !i.isPurchased).toList(),
    );
  }

  Future<void> _mutateItems(List<ShoppingItem> Function(List<ShoppingItem>) fn)
  async {
    final index = _activeListIndex;
    if (index == -1) return;

    _lists[index] = _lists[index].copyWith(
      items: fn(_lists[index].items),
      updatedAt: DateTime.now(),
    );

    notifyListeners();
    await _persist();
  }

  // ------------------------------------------------------------- sharing

  /// Imports a list received from another device.
  ///
  /// A received list keeps its own id when it does not collide with an
  /// existing one, so repeated shares of the same list update rather than
  /// duplicate. Re-sharing an already-held list is treated as an update.
  Future<ShoppingList> importList(SharedListPayload payload) async {
    final incoming = payload.list;
    final existing = _lists.indexWhere((l) => l.id == incoming.id);

    final imported = incoming.copyWith(
      updatedAt: DateTime.now(),
      items: incoming.items
          .map((i) => ShoppingItem(id: _idFactory(), name: i.name,
              quantity: i.quantity, category: i.category,
              isPurchased: i.isPurchased))
          .toList(),
    );

    if (existing != -1) {
      _lists[existing] = imported;
    } else {
      _lists.add(imported);
    }

    _activeListId = imported.id;
    _resetFilters();

    notifyListeners();
    await _persist();
    return imported;
  }

  // ------------------------------------------------------------- filters

  void setItemFilter(ItemFilter value) {
    if (_itemFilter == value) return;
    _itemFilter = value;
    notifyListeners();
  }

  void setCategoryFilter(Category? value) {
    if (_categoryFilter == value) return;
    _categoryFilter = value;
    notifyListeners();
  }

  void _resetFilters() {
    _itemFilter = ItemFilter.all;
    _categoryFilter = null;
  }

  // -------------------------------------------------------------- helpers

  int _indexOf(String id) => _lists.indexWhere((l) => l.id == id);

  int get _activeListIndex => _activeListId == null
      ? -1
      : _indexOf(_activeListId!);
}
