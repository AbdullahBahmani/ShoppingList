import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multipeer_bridge/multipeer_bridge.dart';
import 'package:provider/provider.dart';

import '../models/shopping_list.dart';
import '../providers/shopping_lists_provider.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';

/// Opens the nearby-device share flow for one list.
Future<void> showShareSheet(BuildContext context, String listId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => ShareService()..start(),
      child: _ShareSheet(listId: listId),
    ),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.listId});

  final String listId;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _busyPeers = <String>{};

  @override
  void dispose() {
    // Stop the radio so this device is not left advertising.
    context.read<ShareService>().dispose();
    super.dispose();
  }

  Future<void> _send(ShoppingList list, MultipeerPeer peer) async {
    final service = context.read<ShareService>();

    setState(() {
      _busyPeers.add(peer.id);
      service.clearInbox();
    });

    try {
      if (peer.state != PeerState.connected) {
        await service.invite(peer);
      }
      await service.sendList(list, peer);
      if (!mounted) return;

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent "${list.name}" to ${peer.name}'),
        ),
      );
    } on ShareException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _busyPeers.remove(peer.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.watch<ShareService>();
    final provider = context.watch<ShoppingListsProvider>();

    final list = provider.activeLists
        .where((l) => l.id == widget.listId)
        .firstOrNull;

    if (list == null) {
      return const SizedBox.shrink();
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            _Grabber(),
            _Header(list: list, service: service),

            if (service.errors.isNotEmpty)
              for (final error in service.errors)
                _ErrorBanner(message: error),

            Expanded(
              child: service.peers.isEmpty
                  ? _SearchingState(deviceName: service.displayName)
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        Insets.lg,
                        Insets.md,
                        Insets.lg,
                        Insets.md,
                      ),
                      itemCount: service.peers.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Insets.sm),
                      itemBuilder: (context, index) {
                        final peer = service.peers[index];
                        return _PeerTile(
                          peer: peer,
                          isBusy: _busyPeers.contains(peer.id),
                          onSend: () => _send(list, peer),
                        );
                      },
                    ),
            ),

            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.sm,
                  Insets.lg,
                  Insets.lg,
                ),
                child: Text(
                  'Keep both devices nearby and unlocked, with Bluetooth '
                  'or WiFi turned on.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Grabber extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: Insets.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(Corners.pill),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.list, required this.service});

  final ShoppingList list;
  final ShareService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: Row(
            children: [
              Icon(Icons.ios_share, color: theme.colorScheme.primary),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      list.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${list.totalItems} '
                      '${list.totalItems == 1 ? 'item' : 'items'} · visible as '
                      '"${service.displayName}"',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        const Divider(height: 1),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, 0),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(Corners.sm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchingState extends StatelessWidget {
  const _SearchingState({required this.deviceName});

  final String deviceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: Insets.xl),
        Text(
          'Looking for nearby devices',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Insets.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          child: Text(
            'On the other device, open its Receive tab to appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _PeerTile extends StatelessWidget {
  const _PeerTile({
    required this.peer,
    required this.isBusy,
    required this.onSend,
  });

  final MultipeerPeer peer;
  final bool isBusy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = peer.state == PeerState.connected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smartphone,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    peer.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isConnected ? 'Connected' : 'Tap send to invite',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isConnected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            FilledButton(
              onPressed: isBusy ? null : onSend,
              style: FilledButton.styleFrom(
                minimumSize: const Size(76, 44),
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              ),
              child: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
