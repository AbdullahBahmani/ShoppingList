import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopping_list/data/list_storage.dart';
import 'package:shopping_list/models/shopping_item.dart';
import 'package:shopping_list/models/shopping_list.dart';
import 'package:shopping_list/providers/shopping_lists_provider.dart';
import 'package:shopping_list/screens/link_import_screen.dart';
import 'package:shopping_list/services/link_codec.dart';
import 'package:shopping_list/services/share_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final senderList = ShoppingList(
    id: 'sender-1',
    name: 'Farmers market',
    createdAt: DateTime(2026, 3, 4, 9, 30),
    updatedAt: DateTime(2026, 3, 5),
    items: const [
      ShoppingItem(id: 'a', name: 'Sourdough loaf', quantity: 1,
          category: Category.bakery),
      ShoppingItem(id: 'b', name: 'Free range eggs', quantity: 12,
          category: Category.dairy),
      ShoppingItem(id: 'c', name: 'Heirloom tomatoes', quantity: 4,
          category: Category.produce, isPurchased: true),
    ],
  );

  /// The link a recipient would receive, decoded exactly as the app does.
  SharedListPayload decodedLink() =>
      ListLinkCodec.decode(ListLinkCodec.encode(senderList))!;

  Future<ShoppingListsProvider> makeProvider() async {
    final provider = ShoppingListsProvider(
      storage: ListStorage(),
      idFactory: () => 'local-${DateTime.now().microsecondsSinceEpoch}',
    );
    await provider.load();
    return provider;
  }

  group('LinkImportScreen', () {
    testWidgets('previews the shared list before importing', (tester) async {
      final provider = await makeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: LinkImportScreen(payload: decodedLink()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Farmers market'), findsOneWidget);
      expect(find.text('Sourdough loaf'), findsOneWidget);
      expect(find.text('Free range eggs'), findsOneWidget);
      expect(find.text('Heirloom tomatoes'), findsOneWidget);
      expect(find.text('×12'), findsOneWidget);
    });

    testWidgets('does not import until the user confirms', (tester) async {
      final provider = await makeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: LinkImportScreen(payload: decodedLink()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(provider.activeLists, isEmpty);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(provider.activeLists, isEmpty);
    });

    testWidgets('adds the list to my lists on confirm', (tester) async {
      final provider = await makeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: LinkImportScreen(payload: decodedLink()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to my lists'));
      await tester.pumpAndSettle();

      expect(provider.activeLists.length, 1);
      final imported = provider.activeLists.single;
      expect(imported.name, 'Farmers market');
      expect(imported.items.length, 3);
      expect(
        imported.items.firstWhere((i) => i.name == 'Free range eggs').quantity,
        12,
      );
      expect(
        imported.items
            .firstWhere((i) => i.name == 'Heirloom tomatoes')
            .isPurchased,
        isTrue,
      );
    });

    testWidgets('handles a shared empty list', (tester) async {
      final provider = await makeProvider();
      final empty = ShoppingList(
        id: 'sender-2',
        name: 'Nothing yet',
        createdAt: DateTime(2026, 3, 4),
        updatedAt: DateTime(2026, 3, 4),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: LinkImportScreen(
              payload: ListLinkCodec.decode(ListLinkCodec.encode(empty))!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This list is empty.'), findsOneWidget);

      await tester.tap(find.text('Add to my lists'));
      await tester.pumpAndSettle();

      expect(provider.activeLists.single.name, 'Nothing yet');
    });
  });

  group('link import into the provider', () {
    test('keeps an existing local list when importing a link', () async {
      final provider = await makeProvider();
      await provider.createList('My own list');

      await provider.importList(decodedLink());

      expect(provider.activeLists.length, 2);
      expect(
        provider.activeLists.map((l) => l.name),
        containsAll(['My own list', 'Farmers market']),
      );
    });

    test('re-importing the same link updates instead of duplicating', () async {
      final provider = await makeProvider();

      await provider.importList(decodedLink());
      expect(provider.activeLists.length, 1);

      await provider.importList(decodedLink());
      expect(provider.activeLists.length, 1);
    });

    test('imported items get local ids, not the sender ids', () async {
      final provider = await makeProvider();
      final imported = await provider.importList(decodedLink());

      final senderIds = senderList.items.map((i) => i.id).toSet();
      final localIds = imported.items.map((i) => i.id).toSet();

      expect(
        senderIds.intersection(localIds),
        isEmpty,
        reason: 'import should regenerate item ids',
      );
    });

    test('a second app installing the same link converges', () async {
      final first = await makeProvider();
      await first.importList(decodedLink());
      await first.addItem(name: 'Local addition');

      final second = await makeProvider();
      final received = await second.importList(decodedLink());

      expect(received.name, 'Farmers market');
      expect(
        received.items.any((i) => i.name == 'Local addition'),
        isFalse,
        reason: 'import overwrites rather than merging local edits',
      );
    });
  });
}
