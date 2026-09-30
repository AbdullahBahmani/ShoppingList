import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/shopping_lists_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/list_card.dart';
import 'archive_screen.dart';
import 'list_detail_screen.dart';
import 'receive_screen.dart';

/// Home screen listing every active shopping list.
class ListsHomeScreen extends StatelessWidget {
  const ListsHomeScreen({super.key});

  Future<void> _createList(BuildContext context) async {
    final provider = context.read<ShoppingListsProvider>();
    final name = await showListNameDialog(context);
    if (name == null) return;

    await provider.createList(name);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingListsProvider>();
    final lists = provider.activeLists;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Lists'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ReceiveScreen()),
            ),
            icon: const Icon(Icons.bluetooth_searching),
            tooltip: 'Receive a shared list',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ArchiveScreen()),
            ),
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Archive',
          ),
          IconButton(
            onPressed: () => _createList(context),
            icon: const Icon(Icons.add),
            tooltip: 'New list',
          ),
          const SizedBox(width: Insets.xs),
        ],
      ),
      floatingActionButton: lists.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _createList(context),
              icon: const Icon(Icons.playlist_add),
              label: const Text('New list'),
            ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : lists.isEmpty
          ? EmptyState(
              icon: Icons.shopping_basket_outlined,
              title: 'No lists yet',
              message:
                  'Create a list for your next shop, then share it with '
                  'someone nearby.',
              actionLabel: 'Create your first list',
              onAction: () => _createList(context),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                // Clear the extended FAB and the home indicator.
                104,
              ),
              itemCount: lists.length,
              separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
              itemBuilder: (context, index) {
                final list = lists[index];
                return ListCard(
                  list: list,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ListDetailScreen(listId: list.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Shared dialog for naming a new list. Returns null when cancelled.
///
/// The controller is owned by [_ListNameDialog] so it is disposed with the
/// dialog's own element, not while the exit animation is still rebuilding.
Future<String?> showListNameDialog(
  BuildContext context, {
  String title = 'New list',
  String confirmLabel = 'Create',
  String initialValue = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ListNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
    ),
  );
}

class _ListNameDialog extends StatefulWidget {
  const _ListNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialValue,
  });

  final String title;
  final String confirmLabel;
  final String initialValue;

  @override
  State<_ListNameDialog> createState() => _ListNameDialogState();
}

class _ListNameDialogState extends State<_ListNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        maxLength: 60,
        decoration: const InputDecoration(
          labelText: 'List name',
          hintText: 'e.g. Weekly shop',
          counterText: '',
          border: OutlineInputBorder(),
        ),
        onSubmitted: _submit,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _submit(_controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
