import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shopping_item.dart';
import '../providers/shopping_lists_provider.dart';
import '../services/list_sharing.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_tile.dart';
import '../widgets/list_card.dart';
import 'add_item_sheet.dart';
import 'lists_home_screen.dart';
import 'share_sheet.dart';

/// Item view for a single list, addressed by id so it survives rebuilds.
class ListDetailScreen extends StatelessWidget {
  const ListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingListsProvider>();
    final list = provider.activeList;

    // Guard against the list being deleted while this screen is open.
    if (list == null || list.id != listId) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off,
          title: 'List not found',
          message: 'This list is no longer available.',
        ),
      );
    }

    final items = provider.visibleItems;
    final hasFilters =
        provider.itemFilter != ItemFilter.all || provider.categoryFilter != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              list.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${list.activeCount} to buy · ${list.purchasedCount} in cart',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => showListActionsSheet(context, list.id),
            icon: const Icon(Icons.more_vert),
            tooltip: 'List actions',
          ),
          const SizedBox(width: Insets.xs),
        ],
      ),
      floatingActionButton: list.isArchived
          ? null
          : FloatingActionButton.extended(
              onPressed: () => AddItemSheet.show(
                context,
                onSubmit: (name, quantity, category) => provider.addItem(
                  name: name,
                  quantity: quantity,
                  category: category,
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
      body: Column(
        children: [
          if (!list.isArchived) _ProgressHeader(progress: list.progress),
          if (!list.isArchived) _FilterBar(provider: provider),
          const Divider(height: 1),
          Expanded(
            child: list.isArchived
                ? _ArchivedListView(
                    totalItems: list.totalItems,
                    visibleCount: items.length,
                  )
                : items.isEmpty
                ? EmptyState(
                    icon: hasFilters
                        ? Icons.filter_alt_off_outlined
                        : Icons.playlist_add_outlined,
                    title: hasFilters
                        ? 'Nothing matches these filters'
                        : 'This list is empty',
                    message: hasFilters
                        ? 'Try a different filter to see the rest of the items.'
                        : 'Tap "Add item" to start building this list.',
                    actionLabel: hasFilters ? null : 'Add an item',
                    onAction: hasFilters
                        ? null
                        : () => AddItemSheet.show(
                            context,
                            onSubmit: (name, quantity, category) =>
                                provider.addItem(
                                  name: name,
                                  quantity: quantity,
                                  category: category,
                                ),
                          ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(
                      top: Insets.sm,
                      bottom: 104,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Insets.xs),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ItemTile(
                        item: item,
                        readOnly: list.isArchived,
                        onToggle: () => provider.togglePurchased(item.id),
                        onIncrement: () => provider.updateQuantity(
                          item.id,
                          item.quantity + 1,
                        ),
                        onDecrement: () => provider.updateQuantity(
                          item.id,
                          item.quantity - 1,
                        ),
                        onDelete: () => provider.removeItem(item.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (progress * 100).round();
    final isComplete = progress >= 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.md,
        Insets.lg,
        Insets.md,
      ),
      color: theme.colorScheme.surfaceContainer,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Corners.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  isComplete ? theme.colorScheme.primary : theme.colorScheme.secondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: Insets.md),
          Semantics(
            label: '$percent percent of this list complete',
            excludeSemantics: true,
            child: Row(
              children: [
                if (isComplete) ...[
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  '$percent%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isComplete
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.provider});

  final ShoppingListsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.md,
            Insets.md,
            Insets.sm,
          ),
          child: Row(
            children: [
              for (final filter in ItemFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: ChoiceChip(
                    label: Text(switch (filter) {
                      ItemFilter.all => 'All',
                      ItemFilter.toBuy => 'To buy',
                      ItemFilter.inCart => 'In cart',
                    }),
                    selected: provider.itemFilter == filter,
                    onSelected: (_) => provider.setItemFilter(filter),
                  ),
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            0,
            Insets.md,
            Insets.md,
          ),
          child: Row(
            children: [
              for (final category in Category.values)
                Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: FilterChip(
                    avatar: Icon(
                      categoryIcon(category),
                      size: 17,
                      color: provider.categoryFilter == category
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    label: Text(category.label),
                    selected: provider.categoryFilter == category,
                    onSelected: (selected) => provider.setCategoryFilter(
                      selected ? category : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Archived lists are read-only, so the body is a static summary.
class _ArchivedListView extends StatelessWidget {
  const _ArchivedListView({
    required this.totalItems,
    required this.visibleCount,
  });

  final int totalItems;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'Archived list',
      message:
          'This list was archived with $totalItems ${totalItems == 1 ? 'item' : 'items'}. '
          'Restore it from the archive to make changes again.',
    );
  }
}

/// Actions sheet: rename, share, duplicate, archive, clear.
Future<void> showListActionsSheet(BuildContext context, String listId) async {
  final provider = context.read<ShoppingListsProvider>();
  final theme = Theme.of(context);
  final list = provider.activeLists.firstWhere(
    (l) => l.id == listId,
    orElse: () => provider.archivedLists.firstWhere(
      (l) => l.id == listId,
      orElse: () => throw StateError('List $listId not found'),
    ),
  );

  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.lg,
              Insets.lg,
              Insets.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    list.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (!list.isArchived) ...[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename list'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _renameList(context, listId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share to nearby device'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showShareSheet(context, listId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Duplicate list'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                provider.duplicateList(listId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Share as a link'),
              subtitle: const Text('Send over Messages, SMS or Mail'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                shareListViaLink(context, list);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rtl),
              title: Text(
                'Clear in-cart items'
                '${list.purchasedCount > 0 ? ' (${list.purchasedCount})' : ''}',
              ),
              enabled: list.purchasedCount > 0,
              onTap: () {
                Navigator.of(sheetContext).pop();
                provider.clearPurchasedItems();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.archive_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                'Archive list',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              subtitle: const Text('Keeps it as a read-only snapshot'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                provider.archiveList(listId);
                commitHaptic();
                context.read<ShoppingListsProvider>();
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.unarchive_outlined),
              title: const Text('Restore list'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                provider.restoreList(listId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Duplicate as new list'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                provider.duplicateList(listId);
              },
            ),
          ],

          const SizedBox(height: Insets.sm),
        ],
      ),
    ),
  );
}

Future<void> _renameList(BuildContext context, String listId) async {
  final provider = context.read<ShoppingListsProvider>();
  final current = provider.activeLists.firstWhere(
    (l) => l.id == listId,
    orElse: () => provider.archivedLists.firstWhere((l) => l.id == listId),
  );

  final name = await showListNameDialog(
    context,
    title: 'Rename list',
    confirmLabel: 'Save',
    initialValue: current.name,
  );

  if (name != null) {
    await provider.renameList(listId, name);
  }
}
