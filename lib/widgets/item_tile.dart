import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/shopping_item.dart';
import '../theme/app_theme.dart';
import 'list_card.dart';

/// One row in a list. Swipe left to delete when not read-only.
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
    this.readOnly = false,
  });

  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final row = _buildRow(context);

    if (readOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        child: row,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          HapticFeedback.mediumImpact();
          onDelete();
        },
        background: _DeleteBackground(),
        child: row,
      ),
    );
  }

  Widget _buildRow(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      // Tapping anywhere on the row toggles, so the target is the full row
      // rather than only the 24pt checkbox.
      child: InkWell(
        borderRadius: BorderRadius.circular(Corners.md),
        onTap: readOnly
            ? null
            : () {
                HapticFeedback.selectionClick();
                onToggle();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm,
            vertical: Insets.xs,
          ),
          child: Row(
            children: [
              if (readOnly)
                Padding(
                  padding: const EdgeInsets.only(left: Insets.sm),
                  child: Icon(
                    item.isPurchased
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: item.isPurchased
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                )
              else
                Checkbox(
                  value: item.isPurchased,
                  onChanged: (_) {
                    HapticFeedback.selectionClick();
                    onToggle();
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),

              const SizedBox(width: Insets.xs),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        decoration: item.isPurchased
                            ? TextDecoration.lineThrough
                            : null,
                        decorationThickness: 2,
                        color: item.isPurchased
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          categoryIcon(item.category),
                          size: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        // Flexible so a long category label cannot overflow
                        // the row when the item name wraps.
                        Flexible(
                          child: Text(
                            item.category.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (readOnly)
                Padding(
                  padding: const EdgeInsets.only(right: Insets.md),
                  child: Text(
                    '×${item.quantity}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                _QuantityStepper(
                  quantity: item.quantity,
                  onIncrement: onIncrement,
                  onDecrement: onDecrement,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: Insets.lg),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(Corners.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.delete_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 6),
          Text(
            'Delete',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDecrement = quantity > 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // SizedBox holds the tap target at 44pt even though the icon is 20.
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: canDecrement
                ? () {
                    HapticFeedback.selectionClick();
                    onDecrement();
                  }
                : null,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            padding: EdgeInsets.zero,
            tooltip: canDecrement
                ? 'Decrease quantity'
                : 'Minimum quantity is 1',
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              onIncrement();
            },
            icon: const Icon(Icons.add_circle_outline, size: 20),
            padding: EdgeInsets.zero,
            tooltip: 'Increase quantity',
          ),
        ),
      ],
    );
  }
}
