import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/shopping_item.dart';
import '../models/shopping_list.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';

/// Summary card for one list, shown on the home and archive screens.
class ListCard extends StatelessWidget {
  const ListCard({
    super.key,
    required this.list,
    required this.onTap,
    this.onArchive,
    this.onRestore,
    this.onDuplicate,
    this.onDelete,
  });

  final ShoppingList list;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label:
          '${list.name}, ${list.activeCount} to buy, ${list.purchasedCount} in cart',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(Corners.sm),
                      ),
                      child: Icon(
                        categoryIcon(list.dominantCategory),
                        size: 22,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            list.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatRelativeDate(list.updatedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_hasMenuActions)
                      _OverflowMenu(
                        onArchive: onArchive,
                        onRestore: onRestore,
                        onDuplicate: onDuplicate,
                        onDelete: onDelete,
                      ),
                  ],
                ),

                const SizedBox(height: Insets.lg),

                if (list.isArchived) ...[
                  _ArchivedBadge(itemCount: list.totalItems),
                ] else ...[
                  _ProgressBar(
                    value: list.progress,
                    isComplete: list.isComplete,
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      _CountChip(
                        icon: Icons.shopping_cart_outlined,
                        label: '${list.activeCount} to buy',
                      ),
                      const SizedBox(width: Insets.sm),
                      _CountChip(
                        icon: Icons.check_circle_outline,
                        label: '${list.purchasedCount} in cart',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasMenuActions =>
      onArchive != null ||
      onRestore != null ||
      onDuplicate != null ||
      onDelete != null;
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.isComplete});

  final double value;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Corners.pill),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                isComplete ? scheme.primary : scheme.secondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: Insets.md),
        Semantics(
          label: '${(value * 100).round()} percent complete',
          excludeSemantics: true,
          child: Text(
            '${(value * 100).round()}%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Corners.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedBadge extends StatelessWidget {
  const _ArchivedBadge({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.inventory_2_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          'Archived · $itemCount ${itemCount == 1 ? 'item' : 'items'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    this.onArchive,
    this.onRestore,
    this.onDuplicate,
    this.onDelete,
  });

  final VoidCallback? onArchive;
  final VoidCallback? onRestore;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'List actions',
      onSelected: (value) {
        switch (value) {
          case 'archive':
            onArchive?.call();
          case 'restore':
            onRestore?.call();
          case 'duplicate':
            onDuplicate?.call();
          case 'delete':
            onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        if (onArchive != null)
          const PopupMenuItem(
            value: 'archive',
            child: ListTile(
              leading: Icon(Icons.archive_outlined),
              title: Text('Archive'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (onDuplicate != null)
          const PopupMenuItem(
            value: 'duplicate',
            child: ListTile(
              leading: Icon(Icons.copy_all_outlined),
              title: Text('Duplicate'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (onRestore != null)
          const PopupMenuItem(
            value: 'restore',
            child: ListTile(
              leading: Icon(Icons.unarchive_outlined),
              title: Text('Restore'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Delete permanently'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}

/// Maps a category to its icon in one place so the set stays consistent.
IconData categoryIcon(Category category) => switch (category) {
  Category.produce => Icons.eco_outlined,
  Category.bakery => Icons.bakery_dining_outlined,
  Category.dairy => Icons.egg_outlined,
  Category.meat => Icons.set_meal_outlined,
  Category.pantry => Icons.kitchen_outlined,
  Category.frozen => Icons.ac_unit,
  Category.beverages => Icons.local_drink_outlined,
  Category.household => Icons.cleaning_services_outlined,
  Category.other => Icons.shopping_basket_outlined,
};

/// Confirmation dialog for destructive actions. Returns true when confirmed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Light haptic on destructive or commit actions.
void commitHaptic() => HapticFeedback.lightImpact();
