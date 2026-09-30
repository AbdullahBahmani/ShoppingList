import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/shopping_list.dart';
import '../services/link_codec.dart';
import '../theme/app_theme.dart';

/// Shares a list as a link through the system share sheet, where the user can
/// pick Messages, SMS, Mail, or any other app.
///
/// The whole list travels inside the link, so there is no server and no
/// account involved. This is why long links are called out to the sender.
Future<void> shareListViaLink(BuildContext context, ShoppingList list) async {
  final link = ListLinkCodec.buildShareLink(list);
  final isLong = link.length > ListLinkCodec.recommendedMaxLength;

  final shouldShare = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Share list as a link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Anyone you send this to can open it in the Shopping List app. '
            'No account or internet connection needed.',
            style: Theme.of(dialogContext).textTheme.bodyMedium,
          ),
          const SizedBox(height: Insets.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: Theme.of(dialogContext).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(Corners.sm),
            ),
            child: Text(
              link,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                fontFamily: 'Menlo',
                height: 1.4,
              ),
            ),
          ),
          if (isLong) ...[
            const SizedBox(height: Insets.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    'This is a large list, so the link is long. It may be '
                    'split across several text messages.',
                    style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        dialogContext,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          icon: const Icon(Icons.ios_share, size: 18),
          label: const Text('Share'),
        ),
      ],
    ),
  );

  if (shouldShare != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    // Native: opens the iOS share sheet. Web: uses navigator.share, which
    // offers Messages, SMS and Mail. share_plus falls back to the clipboard
    // when the Web Share API is unavailable.
    final result = await SharePlus.instance.share(
      ShareParams(text: link, subject: list.name),
    );

    if (result.status == ShareResultStatus.dismissed) return;

    if (result.status == ShareResultStatus.unavailable) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Sharing unavailable. The link was copied instead.'),
        ),
      );
    }
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open the share sheet')),
    );
  }
}
