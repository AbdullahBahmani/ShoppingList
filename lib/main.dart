import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/shopping_lists_provider.dart';
import 'screens/link_import_screen.dart';
import 'screens/lists_home_screen.dart';
import 'services/deep_link_service.dart';
import 'services/link_codec.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShoppingListApp());
}

class ShoppingListApp extends StatelessWidget {
  const ShoppingListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // Hydrate from disk before the first frame.
      create: (_) => ShoppingListsProvider()..load(),
      child: MaterialApp(
        title: 'Shopping List',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const _LinkAwareHome(),
      ),
    );
  }
}

/// Hosts the home screen and routes `shoppinglist://` links into the
/// import flow, for both cold and warm starts.
class _LinkAwareHome extends StatefulWidget {
  const _LinkAwareHome();

  @override
  State<_LinkAwareHome> createState() => _LinkAwareHomeState();
}

class _LinkAwareHomeState extends State<_LinkAwareHome> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _sub;
  final _pending = <String>[];

  @override
  void initState() {
    super.initState();

    // A link that cold-started the app arrives before the first frame, so
    // hold it until the navigator exists.
    DeepLinkService.instance.start(
      onColdStartLink: (link) => _pending.add(link),
    );

    _sub = DeepLinkService.instance.links.listen(_handleLink);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handleLink(String rawLink) {
    final payload = ListLinkCodec.parseUri(Uri.parse(rawLink));
    if (payload == null) {
      _notify('That link could not be read');
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      _pending.add(rawLink);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) LinkImportScreen.show(context, payload);
    });
  }

  void _notify(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _drainPending() {
    if (_pending.isEmpty) return;

    final links = List<String>.from(_pending);
    _pending.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final link in links) {
        _handleLink(link);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _drainPending();

    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ListsHomeScreen(),
        );
      },
    );
  }
}
