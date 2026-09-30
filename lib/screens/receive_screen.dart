import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/shopping_lists_provider.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

/// Browsing screen for lists arriving from nearby devices.
class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  late final ShareService _service;
  final _importing = <String>{};

  @override
  void initState() {
    super.initState();
    _service = ShareService()..start();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _import(SharedListPayload payload) async {
    final provider = context.read<ShoppingListsProvider>();

    setState(() => _importing.add(payload.fromDevice));

    await provider.importList(payload);
    if (!mounted) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _importing.remove(payload.fromDevice);
      _service.clearInbox();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "${payload.list.name}" to your lists')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChangeNotifierProvider.value(
      value: _service,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Receive'),
          actions: [
            IconButton(
              onPressed: () => setState(_service.clearInbox),
              icon: const Icon(Icons.refresh),
              tooltip: 'Clear received',
            ),
            const SizedBox(width: Insets.xs),
          ],
        ),
        body: Consumer<ShareService>(
          builder: (context, service, _) {
            if (service.inbox.isEmpty && service.errors.isEmpty) {
              return EmptyState(
                icon: Icons.bluetooth_searching,
                title: 'Listening for lists',
                message:
                    'On the other device, keep this screen open and send a '
                    'list to you. It will appear here.',
              );
            }

            return ListView(
              padding: const EdgeInsets.all(Insets.lg),
              children: [
                for (final error in service.errors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.md),
                    child: _Banner(
                      icon: Icons.error_outline,
                      message: error,
                      isError: true,
                    ),
                  ),

                for (final payload in service.inbox)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.md),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.smartphone,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: Insets.sm),
                                Expanded(
                                  child: Text(
                                    'From ${payload.fromDevice}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Insets.sm),
                            Text(
                              payload.list.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: Insets.xs),
                            Text(
                              '${payload.list.totalItems} '
                              '${payload.list.totalItems == 1 ? 'item' : 'items'}'
                              ' · ${_relativeTime(payload.sentAt)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: Insets.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        setState(_service.clearInbox),
                                    child: const Text('Dismiss'),
                                  ),
                                ),
                                const SizedBox(width: Insets.md),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _importing.contains(
                                      payload.fromDevice,
                                    )
                                        ? null
                                        : () => _import(payload),
                                    child: _importing.contains(payload.fromDevice)
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Add to my lists'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.message,
    required this.isError,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: isError
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Corners.sm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
