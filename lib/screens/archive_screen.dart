import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/shopping_lists_provider.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/empty_state.dart';
import '../widgets/list_card.dart';

/// Read-only history of archived lists, grouped by year.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingListsProvider>();
    final lists = provider.archivedLists;

    return Scaffold(
      appBar: AppBar(title: const Text('Archive')),
      body: lists.isEmpty
          ? const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No archived lists',
              message:
                  'Lists you archive are kept here as read-only snapshots, '
                  'so you can always look back at a past shop.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: Insets.xxl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    Insets.lg,
                    Insets.lg,
                    0,
                  ),
                  child: Text(
                    '${lists.length} archived ${lists.length == 1 ? 'list' : 'lists'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final entry in groupByYear(lists).entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      Insets.xl,
                      Insets.lg,
                      Insets.sm,
                    ),
                    child: Text(
                      entry.key.toString(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final list in entry.value)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.lg,
                        0,
                        Insets.lg,
                        Insets.md,
                      ),
                      child: ListCard(
                        list: list,
                        onTap: () => _confirmRestore(context, list.id, list.name),
                        onRestore: () =>
                            _confirmRestore(context, list.id, list.name),
                        onDuplicate: () => provider.duplicateList(list.id),
                        onDelete: () =>
                            _confirmDelete(context, list.id, list.name),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Future<void> _confirmRestore(
    BuildContext context,
    String id,
    String name,
  ) async {
    final provider = context.read<ShoppingListsProvider>();
    await provider.restoreList(id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$name" restored to your lists'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String id,
    String name,
  ) async {
    final provider = context.read<ShoppingListsProvider>();

    final confirmed = await confirmDestructive(
      context,
      title: 'Delete permanently?',
      message:
          '"$name" and all its items will be erased. This cannot be undone.',
      confirmLabel: 'Delete',
    );

    if (confirmed) {
      await provider.deleteList(id);
      commitHaptic();
    }
  }
}
