import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'link_codec.dart';

/// Watches for `shoppinglist://` links on iOS and `?d=` query parameters on
/// the web, so a shared list lands in the import flow on both platforms.
///
/// Handles both a cold start (the app was not running) and a warm start.
class DeepLinkService with WidgetsBindingObserver {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final _controller = StreamController<String>.broadcast();
  Stream<String> get links => _controller.stream;

  bool _started = false;

  /// Starts listening. [onColdStartLink] is invoked once for a link that
  /// launched the app, because on iOS that link is only readable before the
  /// first frame rather than through the observer below.
  void start({required void Function(String link) onColdStartLink}) {
    if (_started) return;
    _started = true;

    if (kIsWeb) {
      // The browser delivers the whole URL, so there is no separate route
      // stream to observe. The payload stays in the address bar.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final payload = ListLinkCodec.readFromLocation();
        if (payload != null) _controller.add(payload);
      });
      return;
    }

    WidgetsBinding.instance.addObserver(this);

    final initial = PlatformDispatcher.instance.defaultRouteName;
    if (ListLinkCodec.isShareLink(initial)) {
      onColdStartLink(initial);
    }
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final link = routeInformation.uri.toString();
    if (ListLinkCodec.isShareLink(link)) _controller.add(link);

    // Returning false lets the engine treat the link as unhandled, which
    // keeps normal in-app navigation behaviour intact.
    return false;
  }

  @override
  Future<bool> didPushRoute(String route) async {
    if (ListLinkCodec.isShareLink(route)) _controller.add(route);
    return false;
  }
}
