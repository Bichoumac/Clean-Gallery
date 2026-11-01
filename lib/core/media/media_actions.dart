import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_actions.g.dart';

/// Actions on media shared by the grid, the viewer and the trash.
///
/// Every delete goes through the app trash first (`MediaActions.trash`);
/// only the trash deletes for good (`MediaActions.deleteForever`).
@Riverpod(keepAlive: true)
MediaActions mediaActions(Ref ref) => MediaActions(ref);

/// See [mediaActions].
final class MediaActions {
  /// Creates the actions; [_ref] reads services and refreshes lists.
  MediaActions(this._ref);

  final Ref _ref;

  /// Moves [items] to the app trash for the retention set in Settings.
  Future<void> trash(List<MediaItem> items) {
    final days = _ref.read(appSettingsControllerProvider).trashRetentionDays;
    return _ref.read(trashRepositoryProvider).trash(items, retentionDays: days);
  }

  /// Takes the items with [ids] out of the trash.
  Future<void> restore(Iterable<String> ids) =>
      _ref.read(trashRepositoryProvider).restore(ids);

  /// Marks [items] as favorites, or not, in the system gallery. Returns
  /// `false` when the user declined the system prompt.
  ///
  /// The heart switches at once (optimistic update) and switches back if
  /// the request is declined or fails; lists are not reloaded.
  Future<bool> setFavorite(
    List<MediaItem> items, {
    required bool favorite,
  }) async {
    final ids = [for (final item in items) item.id];
    final overrides = _ref.read(favoriteOverridesProvider.notifier)
      ..set(ids, favorite: favorite);
    try {
      final done = await _ref
          .read(platformBridgeProvider)
          .setFavorite(items, favorite: favorite);
      if (done) {
        await _ref
            .read(mediaIndexRepositoryProvider)
            .setFavorite(ids, favorite: favorite);
        // The Favorites album and its count change; reload only those.
        _ref
          ..invalidate(mediaCountProvider)
          ..invalidate(albumCoverProvider)
          ..invalidate(
            mediaListProvider(
              _ref.read(viewSelectionProvider(MediaSelection.favorites)),
            ),
          );
      } else {
        overrides.clear(ids);
      }
      return done;
    } on Object {
      overrides.clear(ids);
      rethrow;
    }
  }

  /// Deletes [items] from the device for good and forgets them in the
  /// trash. Returns `false` when the user declined the system prompt.
  Future<bool> deleteForever(List<MediaItem> items) async {
    final done = await _ref
        .read(platformBridgeProvider)
        .deletePermanently(items);
    if (done) {
      final ids = [for (final item in items) item.id];
      // Hidden first, so they never reappear when their trash entries go.
      _ref.read(deletedIdsProvider.notifier).add(ids);
      await _ref.read(trashRepositoryProvider).forget(ids);
      await _ref.read(userAlbumRepositoryProvider).forget(ids);
      _ref.read(mediaIndexProvider.notifier).changed();
    }
    return done;
  }

  /// Opens the system share sheet for [items].
  Future<void> share(List<MediaItem> items, {required bool removeLocation}) =>
      _ref
          .read(platformBridgeProvider)
          .share(items, removeLocation: removeLocation);
}

/// Moves [items] to the trash and shows a snackbar to undo it.
Future<void> trashWithUndo(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  if (items.isEmpty) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final actions = ref.read(mediaActionsProvider);
  await actions.trash(items);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // With an action, it would stay until closed.
        persist: false,
        content: Text(l10n.trashedSnack(items.length)),
        action: SnackBarAction(
          label: l10n.actionUndo,
          onPressed: () => actions.restore([for (final i in items) i.id]),
        ),
      ),
    );
}

/// Toggles the favorite state of [items]: removes them from favorites when
/// all already are, adds them otherwise. Tells the user if they declined.
Future<void> toggleFavorite(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  if (items.isEmpty) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final favorite = !items.every((i) => i.isFavorite);
  try {
    final done = await ref
        .read(mediaActionsProvider)
        .setFavorite(items, favorite: favorite);
    if (!done) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.favoriteDeclined)));
    }
  } on PlatformException {
    messenger.showSnackBar(SnackBar(content: Text(l10n.favoriteDeclined)));
  }
}

/// Asks how to share [items] (with or without location), then opens the
/// system share sheet.
Future<void> shareWithOptions(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  if (items.isEmpty) return;
  final removeLocation = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => _ShareSheet(
      items: items,
      removeLocationByDefault: ref
          .read(appSettingsControllerProvider)
          .removeGpsOnShare,
    ),
  );
  if (removeLocation == null || !context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(mediaActionsProvider)
        .share(items, removeLocation: removeLocation);
  } on PlatformException {
    messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
  }
}

/// Share options: the location switch (default from Settings) and a
/// warning when videos cannot be stripped.
class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.items,
    required this.removeLocationByDefault,
  });

  final List<MediaItem> items;
  final bool removeLocationByDefault;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  late bool _removeLocation = widget.removeLocationByDefault;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasVideos = widget.items.any((i) => i.isVideo);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shareTitle(widget.items.length),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.shareRemoveLocation),
              subtitle: Text(l10n.shareRemoveLocationHelp),
              value: _removeLocation,
              onChanged: (value) => setState(() => _removeLocation = value),
            ),
            if (hasVideos && _removeLocation)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.shareVideoLocationWarning,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(_removeLocation),
                icon: const Icon(Icons.share_rounded),
                label: Text(l10n.shareButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
