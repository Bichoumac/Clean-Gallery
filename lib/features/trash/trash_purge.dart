import 'package:clean_gallery/core/media/media_actions.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Offers to delete the expired trash for good, at most once a day.
///
/// Called by the shell at launch and when the app comes back to the
/// foreground. With "Media management", expired items are deleted without
/// any prompt. Without it, the user is asked once, then the system shows a
/// single confirmation for the whole batch. Declining waits until the next
/// day. See `docs/features/trash.md` for why this replaces a background
/// job.
Future<void> offerExpiredTrashPurge(BuildContext context, WidgetRef ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final settings = ref.read(appSettingsControllerProvider.notifier);
  if (ref.read(appSettingsControllerProvider).lastPurgeCheck == today) return;
  await settings.setLastPurgeCheck(today);

  final expired = await ref.read(trashRepositoryProvider).expired(now);
  if (expired.isEmpty || !context.mounted) return;
  final items = [for (final entry in expired) entry.item];
  final actions = ref.read(mediaActionsProvider);

  final managed = await ref
      .read(platformBridgeProvider)
      .isMediaManagementGranted();
  if (managed) {
    await actions.deleteForever(items);
    return;
  }
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.purgeTitle(items.length)),
      content: Text(l10n.purgeBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionLater),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.actionDelete),
        ),
      ],
    ),
  );
  if (confirmed ?? false) await actions.deleteForever(items);
}
