import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/shopping_lists_provider.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/list_card.dart';

/// Confirmation screen for a list arriving through a shared link.
///
/// Shows what will be imported before committing, so a surprise link cannot
/// silently alter the user's lists.
class LinkImportScreen extends StatelessWidget {
  const LinkImportScreen({super.key, required this.payload});

  final SharedListPayload payload;

  static Future<void> show(BuildContext context, SharedListPayload payload) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LinkImportScreen(payload: payload),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = payload.list;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared list'),
        leading: CloseButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(Insets.lg),
            padding: const EdgeInsets.all(Insets.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(Corners.md),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Someone shared a list with you',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${list.totalItems} '
                        '${list.totalItems == 1 ? 'item' : 'items'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: Row(
              children: [
                Text(
                  list.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),

          Expanded(
            child: list.items.isEmpty
                ? Center(
                    child: Text(
                      'This list is empty.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.lg,
                      vertical: Insets.sm,
                    ),
                    itemCount: list.items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Insets.xs),
                    itemBuilder: (context, index) {
                      final item = list.items[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.md,
                            vertical: Insets.md,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                categoryIcon(item.category),
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: Insets.md),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: theme.textTheme.bodyLarge,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '×${item.quantity}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Not now'),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _import(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add to my lists'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final provider = context.read<ShoppingListsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final imported = await provider.importList(payload);
    HapticFeedback.mediumImpact();

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Added "${imported.name}" to your lists')),
    );
  }
}
