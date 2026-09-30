import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/models/shopping_item.dart';
import 'package:shopping_list/models/shopping_list.dart';
import 'package:shopping_list/services/link_codec.dart';

void main() {
  ShoppingList sampleList({int itemCount = 4}) {
    return ShoppingList(
      id: 'local-1',
      name: 'Weekly shop',
      createdAt: DateTime(2026, 3, 4, 9, 30),
      updatedAt: DateTime(2026, 3, 5, 18),
      items: [
        for (var i = 0; i < itemCount; i++)
          ShoppingItem(
            id: 'i$i',
            name: 'Item number $i',
            quantity: i + 1,
            category: Category.values[i % Category.values.length],
            isPurchased: i.isEven,
          ),
      ],
    );
  }

  group('ListLinkCodec round trip', () {
    test('preserves list name and items', () {
      final original = sampleList();
      final decoded = ListLinkCodec.decode(ListLinkCodec.encode(original));

      expect(decoded, isNotNull);
      expect(decoded!.list.name, 'Weekly shop');
      expect(decoded.list.items.length, 4);
    });

    test('preserves quantity, category and purchased state', () {
      final original = sampleList();
      final decoded = ListLinkCodec.decode(ListLinkCodec.encode(original))!;

      for (var i = 0; i < original.items.length; i++) {
        expect(decoded.list.items[i].name, original.items[i].name);
        expect(decoded.list.items[i].quantity, original.items[i].quantity);
        expect(decoded.list.items[i].category, original.items[i].category);
        expect(
          decoded.list.items[i].isPurchased,
          original.items[i].isPurchased,
        );
      }
    });

    test('handles an empty list', () {
      final empty = sampleList(itemCount: 0);
      final decoded = ListLinkCodec.decode(ListLinkCodec.encode(empty));

      expect(decoded, isNotNull);
      expect(decoded!.list.items, isEmpty);
    });

    test('handles unicode in item names', () {
      final list = ShoppingList(
        id: 'l',
        name: 'Migrate à Noël — 清单',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        items: const [
          ShoppingItem(id: 'a', name: 'Crème fraîche', quantity: 2),
          ShoppingItem(id: 'b', name: '餅干'),
        ],
      );

      final decoded = ListLinkCodec.decode(ListLinkCodec.encode(list))!;

      expect(decoded.list.name, 'Migrate à Noël — 清单');
      expect(decoded.list.items[0].name, 'Crème fraîche');
      expect(decoded.list.items[1].name, '餅干');
    });

    test('produces a stable id so re-importing updates rather than duplicates',
        () {
      final list = sampleList();
      final first = ListLinkCodec.decode(ListLinkCodec.encode(list))!;
      final second = ListLinkCodec.decode(ListLinkCodec.encode(list))!;

      expect(first.list.id, second.list.id);
    });

    test('decodes a link produced by the original dart:io gzip encoder', () {
      // Links shared before the move to package:archive must still import.
      final legacyPayload = <String, dynamic>{
        'v': 1,
        'n': 'Legacy list',
        'c': DateTime(2026, 3, 4).toUtc().millisecondsSinceEpoch,
        'i': [
          {'n': 'Old item', 'q': 3, 'c': 'dairy', 'd': true},
        ],
      };
      final legacy = base64Url
          .encode(GZipCodec().encode(utf8.encode(jsonEncode(legacyPayload))))
          .replaceAll('=', '');

      final decoded = ListLinkCodec.decode(legacy);

      expect(decoded, isNotNull);
      expect(decoded!.list.name, 'Legacy list');
      expect(decoded.list.items.single.name, 'Old item');
      expect(decoded.list.items.single.quantity, 3);
      expect(decoded.list.items.single.isPurchased, isTrue);
    });

    test('produces a link the original dart:io gzip decoder can read', () {
      // The reverse direction, so a link from the web build stays readable
      // by an older native build.
      final encoded = ListLinkCodec.encode(sampleList());

      final decodedJson = utf8.decode(
        GZipCodec().decode(base64Url.decode(_pad(encoded))),
      );
      final payload = jsonDecode(decodedJson) as Map<String, dynamic>;

      expect(payload['v'], 1);
      expect(payload['n'], 'Weekly shop');
    });
  });

  group('ListLinkCodec link building', () {
    test('builds a shoppinglist://import uri', () {
      final uri = ListLinkCodec.buildUri(sampleList());

      expect(uri.scheme, 'shoppinglist');
      expect(uri.host, 'import');
      expect(uri.queryParameters.containsKey('d'), isTrue);
    });

    test('round trips through buildUri and parseUri', () {
      final original = sampleList();
      final uri = ListLinkCodec.buildUri(original);
      final decoded = ListLinkCodec.parseUri(uri);

      expect(decoded, isNotNull);
      expect(decoded!.list.name, original.name);
      expect(decoded.list.items.length, original.items.length);
    });

    test('the payload stays URL safe', () {
      final encoded = ListLinkCodec.encode(sampleList());

      expect(encoded, isNot(contains('+')));
      expect(encoded, isNot(contains('/')));
      expect(encoded, isNot(contains('=')));
    });

    test('the full link has no characters that need escaping', () {
      final link = ListLinkCodec.buildUri(sampleList()).toString();

      // A raw '+' or '/' inside the query would break the link in a message.
      expect(link, startsWith('shoppinglist://import?'));
      expect(link, isNot(contains(' ')));
      expect(Uri.parse(link).queryParameters.containsKey('d'), isTrue);
    });

    test('a typical list produces a reasonably short link', () {
      final link = ListLinkCodec.buildUri(sampleList(itemCount: 15)).toString();

      expect(
        link.length,
        lessThan(ListLinkCodec.recommendedMaxLength),
        reason: '15 items should still fit in a single text message',
      );
    });
  });

  group('ListLinkCodec rejects bad input', () {
    test('returns null for an empty payload', () {
      expect(ListLinkCodec.decode(''), isNull);
    });

    test('returns null for non-base64 text', () {
      expect(ListLinkCodec.decode('not a real payload!!'), isNull);
    });

    test('returns null for valid base64 that is not gzip', () {
      final notGzip = base64Url
          .encode(utf8.encode('plain text, not compressed'))
          .replaceAll('=', '');

      expect(ListLinkCodec.decode(notGzip), isNull);
    });

    test('returns null for an unsupported version', () {
      // Compress a well-formed payload carrying a future version number.
      final encoded = _encodePayload({'v': 99, 'n': 'x', 'i': []});

      expect(encoded, isNotEmpty);
      expect(ListLinkCodec.decode(encoded), isNull);
    });

    test('ignores a uri with a different scheme', () {
      expect(
        ListLinkCodec.parseUri(Uri.parse('https://example.com/import?d=abc')),
        isNull,
      );
    });

    test('ignores a uri with no payload', () {
      expect(
        ListLinkCodec.parseUri(Uri.parse('shoppinglist://import')),
        isNull,
      );
    });

    test('isShareLink only matches the shoppinglist scheme', () {
      expect(
        ListLinkCodec.isShareLink('shoppinglist://import?d=abc'),
        isTrue,
      );
      expect(ListLinkCodec.isShareLink('https://example.com'), isFalse);
      expect(ListLinkCodec.isShareLink('/'), isFalse);
    });
  });
}

/// Builds a codec-shaped payload from an arbitrary map, so tests can craft
/// inputs the encoder would never produce.
String _encodePayload(Map<String, dynamic> payload) {
  final compressed = GZipCodec().encode(utf8.encode(jsonEncode(payload)));
  return base64Url.encode(compressed).replaceAll('=', '');
}

/// Restores base64 padding stripped by the codec.
String _pad(String value) {
  final remainder = value.length % 4;
  return remainder == 0
      ? value
      : value.padRight(value.length + (4 - remainder), '=');
}
