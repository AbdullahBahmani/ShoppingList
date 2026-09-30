import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopping_list/data/list_storage.dart';
import 'package:shopping_list/models/shopping_item.dart';
import 'package:shopping_list/models/shopping_list.dart';
import 'package:shopping_list/providers/shopping_lists_provider.dart';
import 'package:shopping_list/screens/list_detail_screen.dart';
import 'package:shopping_list/screens/lists_home_screen.dart';
import 'package:shopping_list/services/share_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Deterministic ids so assertions can reference specific items.
  var idCounter = 0;
  String nextId() => 'id-${idCounter++}';

  Future<ShoppingListsProvider> makeProvider() async {
    final provider = ShoppingListsProvider(
      storage: ListStorage(),
      idFactory: nextId,
    );
    await provider.load();
    return provider;
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    ShoppingListsProvider provider,
    Widget screen,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ShoppingList model', () {
    test('computes progress and completion', () {
      final list = ShoppingList(
        id: 'l1',
        name: 'Weekly',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        items: [
          ShoppingItem(id: 'a', name: 'Milk', isPurchased: true),
          ShoppingItem(id: 'b', name: 'Bread'),
          ShoppingItem(id: 'c', name: 'Eggs'),
          ShoppingItem(id: 'd', name: 'Apples', isPurchased: true),
        ],
      );

      expect(list.purchasedCount, 2);
      expect(list.activeCount, 2);
      expect(list.progress, 0.5);
      expect(list.isComplete, isFalse);
    });

    test('an empty list is not considered complete', () {
      final list = ShoppingList(
        id: 'l1',
        name: 'Empty',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(list.progress, 0);
      expect(list.isComplete, isFalse);
    });

    test('round-trips through JSON', () {
      final original = ShoppingList(
        id: 'l1',
        name: 'Party',
        createdAt: DateTime(2026, 3, 4),
        updatedAt: DateTime(2026, 3, 5),
        isArchived: true,
        items: [
          ShoppingItem(
            id: 'i1',
            name: 'Chips',
            quantity: 3,
            category: Category.pantry,
            isPurchased: true,
          ),
        ],
      );

      final restored = ShoppingList.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.isArchived, isTrue);
      expect(restored.items.single.category, Category.pantry);
      expect(restored.items.single.quantity, 3);
      expect(restored.items.single.isPurchased, isTrue);
    });

    test('falls back to other for an unknown category', () {
      final item = ShoppingItem.fromJson({
        'id': 'i1',
        'name': 'Mystery',
        'category': 'not-a-real-category',
      });

      expect(item.category, Category.other);
    });

    test('finds the most frequent category', () {
      final list = ShoppingList(
        id: 'l1',
        name: 'Mixed',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        items: [
          ShoppingItem(id: 'a', name: 'Milk', category: Category.dairy),
          ShoppingItem(id: 'b', name: 'Yogurt', category: Category.dairy),
          ShoppingItem(id: 'c', name: 'Bread', category: Category.bakery),
        ],
      );

      expect(list.dominantCategory, Category.dairy);
    });
  });

  group('ShareService payloads', () {
    test('round-trips a list', () {
      final payload = SharedListPayload(
        fromDevice: "Sam's iPhone",
        sentAt: DateTime(2026, 5, 1, 10, 30),
        list: ShoppingList(
          id: 'l1',
          name: 'Shared shop',
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
          items: [ShoppingItem(id: 'i1', name: 'Coffee', quantity: 2)],
        ),
      );

      final decoded = ShareService.decode(
        // Round-trip through JSON exactly as the transport would.
        jsonEncode(payload.toJson()),
      );

      expect(decoded, isNotNull);
      expect(decoded!.fromDevice, "Sam's iPhone");
      expect(decoded.list.name, 'Shared shop');
      expect(decoded.list.items.single.quantity, 2);
    });

    test('rejects an unsupported version', () {
      expect(ShareService.decode('{"version":99}'), isNull);
    });

    test('rejects malformed json', () {
      expect(ShareService.decode('not json at all'), isNull);
    });

    test('rejects a payload missing the list', () {
      expect(
        ShareService.decode('{"version":1,"fromDevice":"x"}'),
        isNull,
      );
    });
  });

  group('ShoppingListsProvider', () {
    test('starts empty and reports loading complete', () async {
      final provider = await makeProvider();

      expect(provider.isLoading, isFalse);
      expect(provider.activeLists, isEmpty);
      expect(provider.activeList, isNull);
    });

    test('creates a list and makes it active', () async {
      final provider = await makeProvider();
      await provider.createList('Weekly shop');

      expect(provider.activeLists.length, 1);
      expect(provider.activeList!.name, 'Weekly shop');
    });

    test('names an untitled list rather than storing blank', () async {
      final provider = await makeProvider();
      await provider.createList('   ');

      expect(provider.activeList!.name, 'Untitled list');
    });

    test('adds items to the active list', () async {
      final provider = await makeProvider();
      await provider.createList('Weekly');
      await provider.addItem(
        name: '  Milk  ',
        quantity: 2,
        category: Category.dairy,
      );

      final item = provider.activeList!.items.single;
      expect(item.name, 'Milk', reason: 'name should be trimmed');
      expect(item.quantity, 2);
      expect(item.category, Category.dairy);
    });

    test('clamps quantity to a minimum of one', () async {
      final provider = await makeProvider();
      await provider.createList('Weekly');
      await provider.addItem(name: 'Milk', quantity: 0);
      await provider.addItem(name: 'Bread');
      await provider.updateQuantity(provider.activeList!.items.last.id, -5);

      for (final item in provider.activeList!.items) {
        expect(item.quantity, 1);
      }
    });

    test('ignores a blank item name', () async {
      final provider = await makeProvider();
      await provider.createList('Weekly');
      await provider.addItem(name: '   ');

      expect(provider.activeList!.items, isEmpty);
    });

    test('toggles purchased state', () async {
      final provider = await makeProvider();
      await provider.createList('Weekly');
      await provider.addItem(name: 'Milk');
      final id = provider.activeList!.items.single.id;

      await provider.togglePurchased(id);
      expect(provider.activeList!.items.single.isPurchased, isTrue);

      await provider.togglePurchased(id);
      expect(provider.activeList!.items.single.isPurchased, isFalse);
    });

    test('clears only purchased items', () async {
      final provider = await makeProvider();
      await provider.createList('Weekly');
      await provider.addItem(name: 'Milk');
      await provider.addItem(name: 'Bread');

      final first = provider.activeList!.items.first;
      await provider.togglePurchased(first.id);
      await provider.clearPurchasedItems();

      final names = provider.activeList!.items.map((i) => i.name).toList();
      expect(names, ['Bread']);
    });

    test('archives a list and hides it from the active view', () async {
      final provider = await makeProvider();
      await provider.createList('Old shop');
      await provider.addItem(name: 'Milk');
      final id = provider.activeList!.id;

      await provider.archiveList(id);

      expect(provider.activeLists, isEmpty);
      expect(provider.archivedLists.length, 1);
      // With every list archived there is no active list to edit.
      expect(provider.activeList!.isArchived, isTrue);
    });

    test('restores an archived list', () async {
      final provider = await makeProvider();
      final list = await provider.createList('Old shop');
      await provider.archiveList(list.id);
      await provider.restoreList(list.id);

      expect(provider.activeLists.length, 1);
      expect(provider.archivedLists, isEmpty);
    });

    test('deletes a list permanently', () async {
      final provider = await makeProvider();
      final list = await provider.createList('Old shop');
      await provider.archiveList(list.id);
      await provider.deleteList(list.id);

      expect(provider.archivedLists, isEmpty);
      expect(provider.activeLists, isEmpty);
    });

    test('duplicate creates a fresh copy with new item ids', () async {
      final provider = await makeProvider();
      await provider.createList('Weekly');
      await provider.addItem(name: 'Milk', quantity: 2);
      final sourceId = provider.activeList!.id;
      final sourceItemId = provider.activeList!.items.single.id;
      await provider.archiveList(sourceId);

      final copy = await provider.duplicateList(sourceId);

      expect(copy, isNotNull);
      expect(copy!.items.single.name, 'Milk');
      expect(copy.items.single.quantity, 2);
      expect(
        copy.items.single.id,
        isNot(sourceItemId),
        reason: 'duplicate should not reuse item ids',
      );
      expect(copy.isArchived, isFalse, reason: 'copy starts active');
    });

    test('renames a list and ignores blank names', () async {
      final provider = await makeProvider();
      final list = await provider.createList('Weekly');

      await provider.renameList(list.id, '  Weekend  ');
      expect(provider.activeList!.name, 'Weekend');

      await provider.renameList(list.id, '   ');
      expect(provider.activeList!.name, 'Weekend');
    });

    test('selects a list and persists the choice', () async {
      final provider = await makeProvider();
      await provider.createList('First');
      final second = await provider.createList('Second');
      expect(provider.activeList!.name, 'Second');

      await provider.selectList(provider.archivedLists.isEmpty
          ? second.id
          : second.id);
      expect(provider.activeListId, second.id);
    });

    test('filters items by purchase state', () async {
      final provider = await makeProvider();
      await provider.createList('Weekly');
      await provider.addItem(name: 'Milk');
      await provider.addItem(name: 'Bread');
      await provider.togglePurchased(provider.activeList!.items.first.id);

      provider.setItemFilter(ItemFilter.toBuy);
      expect(provider.visibleItems.map((i) => i.name), ['Bread']);

      provider.setItemFilter(ItemFilter.inCart);
      expect(provider.visibleItems.map((i) => i.name), ['Milk']);

      provider.setItemFilter(ItemFilter.all);
      expect(provider.visibleItems.length, 2);
    });

    test('filters items by category', () async {
      final provider = await makeProvider();
      await provider.createList('Weekly');
      await provider.addItem(name: 'Milk', category: Category.dairy);
      await provider.addItem(name: 'Bread', category: Category.bakery);

      provider.setCategoryFilter(Category.dairy);
      expect(provider.visibleItems.map((i) => i.name), ['Milk']);

      provider.setCategoryFilter(null);
      expect(provider.visibleItems.length, 2);
    });

    test('purchased items sort after active ones', () async {
      final provider = await makeProvider();
      await provider.createList('Weekly');
      await provider.addItem(name: 'Milk');
      await provider.addItem(name: 'Bread');
      await provider.togglePurchased(provider.activeList!.items.first.id);

      expect(
        provider.visibleItems.map((i) => i.name),
        ['Bread', 'Milk'],
      );
    });

    test('imports a shared list as a new list', () async {
      final provider = await makeProvider();
      await provider.createList('Mine');

      final imported = await provider.importList(
        SharedListPayload(
          fromDevice: 'Their phone',
          sentAt: DateTime(2026, 6, 1),
          list: ShoppingList(
            id: 'remote-1',
            name: 'From Sam',
            createdAt: DateTime(2026, 6, 1),
            updatedAt: DateTime(2026, 6, 1),
            items: [ShoppingItem(id: 'r1', name: 'Coffee', quantity: 2)],
          ),
        ),
      );

      expect(provider.activeLists.length, 2);
      expect(imported.name, 'From Sam');
      expect(imported.items.single.name, 'Coffee');
      expect(
        imported.items.single.id,
        isNot('r1'),
        reason: 'imported items get local ids',
      );
    });

    test('re-importing the same list updates instead of duplicating', () async {
      final provider = await makeProvider();
      await provider.createList('Mine');

      SharedListPayload payloadFor(String itemName) => SharedListPayload(
        fromDevice: 'Their phone',
        sentAt: DateTime(2026, 6, 1),
        list: ShoppingList(
          id: 'remote-1',
          name: 'From Sam',
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
          items: [ShoppingItem(id: 'r1', name: itemName)],
        ),
      );

      await provider.importList(payloadFor('Coffee'));
      await provider.importList(payloadFor('Tea'));

      final shared = provider.activeLists.where((l) => l.id == 'remote-1');
      expect(shared.length, 1);
      expect(shared.single.items.single.name, 'Tea');
    });

    test('persists lists and the active selection across instances', () async {
      final first = await makeProvider();
      await first.createList('Weekly shop');
      await first.addItem(name: 'Milk', quantity: 3);
      final weeklyId = first.activeList!.id;
      await first.createList('Hardware');

      final second = await makeProvider();

      expect(second.activeLists.length, 2);
      expect(second.activeList!.name, 'Hardware');
      expect(
        second.activeLists
            .firstWhere((l) => l.id == weeklyId)
            .items
            .single
            .quantity,
        3,
      );
    });

    test('migrates legacy single-list storage', () async {
      SharedPreferences.setMockInitialValues({
        'shopping_list_items':
            '[{"id":"a","name":"Legacy Milk","quantity":2,'
            '"category":"dairy","isPurchased":false}]',
      });

      final provider = await makeProvider();

      expect(provider.activeLists.length, 1);
      expect(provider.activeList!.name, 'My List');
      expect(provider.activeList!.items.single.name, 'Legacy Milk');
      expect(provider.activeList!.items.single.quantity, 2);
    });

    test('survives corrupt storage by starting clean', () async {
      SharedPreferences.setMockInitialValues({
        'shopping_lists_v2': '{ this is not valid json',
      });

      final provider = await makeProvider();

      expect(provider.isLoading, isFalse);
      expect(provider.activeLists, isEmpty);
    });

    test('falls back to the newest active list when the pointer is stale', () async {
      SharedPreferences.setMockInitialValues({
        'active_list_id': 'deleted-list-id',
        'shopping_lists_v2':
            '[{"id":"a","name":"One","createdAt":"2026-01-01T00:00:00.000",'
            '"updatedAt":"2026-01-01T00:00:00.000","isArchived":false,"items":[]}]',
      });

      final provider = await makeProvider();

      expect(provider.activeList!.id, 'a');
    });
  });

  group('ListsHomeScreen', () {
    testWidgets('shows the empty state with no lists', (tester) async {
      final provider = await makeProvider();
      await pumpScreen(tester, provider, const ListsHomeScreen());

      expect(find.text('No lists yet'), findsOneWidget);
    });

    testWidgets('lists a created list', (tester) async {
      final provider = await makeProvider();
      await provider.createList('Weekly shop');
      await pumpScreen(tester, provider, const ListsHomeScreen());

      expect(find.text('Weekly shop'), findsOneWidget);
    });

    testWidgets('separates active and archived counts', (tester) async {
      final provider = await makeProvider();
      final done = await provider.createList('Finished');
      await provider.addItem(name: 'Milk');
      await provider.togglePurchased(provider.activeList!.items.single.id);
      await provider.archiveList(done.id);
      await provider.createList('Current');
      await provider.addItem(name: 'Bread');

      await pumpScreen(tester, provider, const ListsHomeScreen());

      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Finished'), findsNothing);
    });

    testWidgets('shows the active list name on the card', (tester) async {
      final provider = await makeProvider();
      await provider.createList('Weekly shop');
      await provider.addItem(name: 'Milk');
      await provider.addItem(name: 'Bread');
      await provider.togglePurchased(provider.activeList!.items.first.id);

      await pumpScreen(tester, provider, const ListsHomeScreen());

      expect(find.text('1 to buy'), findsOneWidget);
      expect(find.text('1 in cart'), findsOneWidget);
    });
  });

  group('ListDetailScreen', () {
    testWidgets('shows an empty state for a list with no items', (
      tester,
    ) async {
      final provider = await makeProvider();
      final list = await provider.createList('Weekly');
      await pumpScreen(
        tester,
        provider,
        ListDetailScreen(listId: list.id),
      );

      expect(find.text('This list is empty'), findsOneWidget);
    });

    testWidgets('renders items with their categories', (tester) async {
      final provider = await makeProvider();
      final list = await provider.createList('Weekly');
      await provider.addItem(name: 'Milk', category: Category.dairy);
      await pumpScreen(
        tester,
        provider,
        ListDetailScreen(listId: list.id),
      );

      expect(find.text('Milk'), findsOneWidget);
      // "Dairy" also appears in the category filter chip row.
      expect(find.text('Dairy'), findsNWidgets(2));
    });

    testWidgets('tapping the row marks an item in cart', (tester) async {
      final provider = await makeProvider();
      final list = await provider.createList('Weekly');
      await provider.addItem(name: 'Milk');
      await pumpScreen(
        tester,
        provider,
        ListDetailScreen(listId: list.id),
      );

      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();

      expect(provider.activeList!.items.single.isPurchased, isTrue);
    });

    testWidgets('hides the add button for an archived list', (tester) async {
      final provider = await makeProvider();
      final list = await provider.createList('Weekly');
      await provider.addItem(name: 'Milk');
      await provider.archiveList(list.id);
      await provider.restoreList(list.id);
      await provider.archiveList(list.id);

      await pumpScreen(
        tester,
        provider,
        ListDetailScreen(listId: list.id),
      );

      expect(find.text('Add item'), findsNothing);
    });

    testWidgets('shows a not-found state for a deleted list', (tester) async {
      final provider = await makeProvider();
      final list = await provider.createList('Weekly');
      await provider.deleteList(list.id);

      await pumpScreen(
        tester,
        provider,
        ListDetailScreen(listId: list.id),
      );

      expect(find.text('List not found'), findsOneWidget);
    });
  });
}
