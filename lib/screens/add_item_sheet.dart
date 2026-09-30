import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/shopping_item.dart';
import '../theme/app_theme.dart';
import '../widgets/list_card.dart';

/// Bottom sheet for composing a new item.
class AddItemSheet extends StatefulWidget {
  const AddItemSheet({super.key, required this.onSubmit});

  final void Function(String name, int quantity, Category category) onSubmit;

  static Future<void> show(
    BuildContext context, {
    required void Function(String name, int quantity, Category category)
    onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddItemSheet(onSubmit: onSubmit),
    );
  }

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  Category _category = Category.other;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    widget.onSubmit(
      _nameController.text,
      int.tryParse(_quantityController.text) ?? 1,
      _category,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      // Lift the sheet clear of the keyboard.
      padding: EdgeInsets.only(
        left: Insets.lg,
        right: Insets.lg,
        top: Insets.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + Insets.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add item',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: Insets.lg),

              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Item name',
                  hintText: 'e.g. Whole milk',
                  counterText: '',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter an item name'
                    : null,
              ),
              const SizedBox(height: Insets.md),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 104,
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Qty'),
                      validator: (value) {
                        final parsed = int.tryParse(value ?? '');
                        if (parsed == null || parsed < 1) return 'Min 1';
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: DropdownButtonFormField<Category>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: Category.values
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Row(
                                children: [
                                  Icon(categoryIcon(c), size: 18),
                                  const SizedBox(width: Insets.sm),
                                  Flexible(
                                    child: Text(
                                      c.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _category = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xl),

              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: const Text('Add to list'),
              ),
              const SizedBox(height: Insets.sm),
            ],
          ),
        ),
      ),
    );
  }
}
