import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/shopping_item.dart';
import '../models/shopping_list.dart';
import 'share_service.dart';

/// Encodes a shopping list into a compact, URL-safe payload for sharing
/// through a link, and decodes it back on the receiving device.
///
/// The payload is a separate versioned wire format rather than the internal
/// model, so ids are regenerated locally and the format can evolve
/// independently of the app's models.
abstract final class ListLinkCodec {
  /// Must match CFBundleURLSchemes in Info.plist.
  static const scheme = 'shoppinglist';
  static const host = 'import';

  /// Format version. Bump when the payload shape changes incompatibly.
  static const version = 1;

  /// Past this length the link becomes awkward inside a text bubble, so the
  /// UI warns the sender.
  static const recommendedMaxLength = 1500;

  /// Builds the shareable link for [list].
  static Uri buildUri(ShoppingList list) {
    return Uri(
      scheme: scheme,
      host: host,
      queryParameters: {'d': encode(list)},
    );
  }

  /// Compresses [list] into a URL-safe string (gzip + unpadded base64url).
  static String encode(ShoppingList list) {
    final payload = <String, dynamic>{
      'v': version,
      'n': list.name,
      'c': list.createdAt.toUtc().millisecondsSinceEpoch,
      'i': [
        for (final item in list.items)
          <String, dynamic>{
            'n': item.name,
            'q': item.quantity,
            'c': item.category.name,
            'd': item.isPurchased,
          },
      ],
    };

    final compressed = GZipEncoder().encodeBytes(
      utf8.encode(jsonEncode(payload)),
    );
    // base64url avoids '+', '/' and '=' which need escaping inside a URL.
    return base64Url.encode(compressed).replaceAll('=', '');
  }

  /// Decodes a payload string. Returns null when it is malformed.
  static SharedListPayload? decode(String encoded) {
    if (encoded.isEmpty) return null;

    try {
      final padded = _padBase64(encoded);
      final decompressed = GZipDecoder().decodeBytes(
        base64Url.decode(padded),
      );
      final payload = jsonDecode(utf8.decode(decompressed)) as Map<String, dynamic>;

      if (payload['v'] != version) return null;

      final rawItems = payload['i'] as List? ?? const [];
      final now = DateTime.now();
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        (payload['c'] as int?) ?? now.millisecondsSinceEpoch,
        isUtc: true,
      ).toLocal();

      return SharedListPayload(
        fromDevice: 'Shared link',
        sentAt: now,
        list: ShoppingList(
          // Ids are regenerated on import, so a fixed id keeps re-imports
          // of the same link updating one list instead of duplicating it.
          id: 'link-${createdAt.millisecondsSinceEpoch}',
          name: payload['n'] as String? ?? 'Shared list',
          createdAt: createdAt,
          updatedAt: now,
          items: [
            for (final raw in rawItems)
              _itemFromJson(raw as Map<String, dynamic>),
          ],
        ),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      // base64 or gzip rejected the input.
      return null;
    }
  }

  /// Parses an incoming [uri]. Returns null when it is not a share link.
  static SharedListPayload? parseUri(Uri uri) {
    if (uri.scheme != scheme) return null;
    final encoded = uri.queryParameters['d'];
    if (encoded == null) return null;
    return decode(encoded);
  }

  static bool isShareLink(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == scheme;
  }

  /// Reads a shared list out of the current browser location.
  ///
  /// On the web a link is just the site's URL with a `d` query parameter, so
  /// the payload is available from [Uri.base]. Returns a canonical
  /// `shoppinglist://import` link when a payload is present, so callers can
  /// treat web and native identically.
  static String? readFromLocation() {
    final encoded = Uri.base.queryParameters['d'];
    if (encoded == null || encoded.isEmpty) return null;

    // Reject early so a bad link is not mistaken for a valid one.
    if (decode(encoded) == null) return null;

    return Uri(
      scheme: scheme,
      host: host,
      queryParameters: {'d': encoded},
    ).toString();
  }

  /// The link to hand to a recipient, resolved against the current origin so
  /// it works as a real https URL on the web.
  static String buildShareLink(ShoppingList list, {Uri? base}) {
    final encoded = encode(list);

    if (kIsWeb) {
      final origin = base ?? Uri.base;
      return origin.replace(
        queryParameters: {...origin.queryParameters, 'd': encoded},
        fragment: '',
      ).toString();
    }

    return buildUri(list).toString();
  }

  static ShoppingItem _itemFromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json.hashCode.toString(),
      name: json['n'] as String? ?? 'Item',
      quantity: (json['q'] as int?) ?? 1,
      category: CategoryX.fromName(json['c'] as String?),
      isPurchased: json['d'] as bool? ?? false,
    );
  }

  /// base64url encoding drops padding; restore it before decoding.
  static String _padBase64(String value) {
    final remainder = value.length % 4;
    if (remainder == 0) return value;
    return value.padRight(value.length + (4 - remainder), '=');
  }
}
