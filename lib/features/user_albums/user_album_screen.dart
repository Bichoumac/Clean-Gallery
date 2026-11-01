import 'dart:async';

import 'package:clean_gallery/core/media/selection_bar.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/features/library/media_timeline_view.dart';
import 'package:clean_gallery/features/user_albums/user_album_actions.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Page of a user album: its timeline, like a folder page, with a menu to
/// rename or delete the album, and *Remove from album* and *Use as cover*
/// in the selection bar.
///
/// Nothing here touches a file: removing an item or deleting the album only
/// changes the album's list. See `docs/features/user-albums.md`.
class UserAlbumScreen extends ConsumerWidget {
  /// Creates the page of album [albumId].
  const UserAlbumScreen({required this.albumId, super.key});

  /// Database id of the album.
  final int albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final albums = ref.watch(userAlbumsProvider).value;
    final album = albums?.where((a) => a.id == albumId).firstOrNull;
    return MediaTimelineView(
      selection: MediaSelection(userAlbumId: albumId),
      title: album?.name ?? '',
      emptyTitle: l10n.libraryEmptyAlbum,
      emptyBody: l10n.userAlbumEmptyBody,
      showBackButton: true,
      showSearch: true,
      headerActions: [
        if (album != null)
          PopupMenuButton<_AlbumAction>(
            tooltip: l10n.userAlbumMenu,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (action) => unawaited(switch (action) {
              _AlbumAction.rename => _rename(context, ref, album),
              _AlbumAction.delete => _delete(context, ref, album),
            }),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _AlbumAction.rename,
                child: Text(l10n.actionRename),
              ),
              PopupMenuItem(
                value: _AlbumAction.delete,
                child: Text(l10n.actionDeleteAlbum),
              ),
            ],
          ),
      ],
      selectionActions: (picked, clearSelection) => [
        SelectionAction(
          icon: Icons.playlist_remove_rounded,
          label: l10n.actionRemoveFromAlbum,
          onPressed: () {
            unawaited(_remove(context, ref, picked));
            clearSelection();
          },
        ),
        if (picked.length == 1)
          SelectionAction(
            icon: Icons.image_outlined,
            label: l10n.actionUseAsCover,
            onPressed: () {
              unawaited(_useAsCover(context, ref, picked.single));
              clearSelection();
            },
          ),
      ],
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    UserAlbum album,
  ) async {
    final name = await askAlbumName(
      context,
      ref,
      initial: album.name,
      renaming: album.id,
    );
    if (name == null || name == album.name) return;
    await ref.read(userAlbumRepositoryProvider).rename(album.id, name);
  }

  /// Asks first, saying the files stay; then closes the page and offers
  /// Undo.
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    UserAlbum album,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(userAlbumRepositoryProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAlbumTitle(album.name)),
        content: Text(l10n.deleteAlbumBody(album.count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.of(context).pop();
    final deleted = await repository.delete(album.id);
    if (deleted == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.albumDeletedSnack),
          action: SnackBarAction(
            label: l10n.actionUndo,
            onPressed: () => unawaited(repository.restore(deleted)),
          ),
        ),
      );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    List<MediaItem> items,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(userAlbumRepositoryProvider);
    final ids = [for (final item in items) item.id];
    await repository.remove(albumId, ids);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.removedFromAlbumSnack(items.length)),
          action: SnackBarAction(
            label: l10n.actionUndo,
            onPressed: () => unawaited(repository.add(albumId, ids)),
          ),
        ),
      );
  }

  Future<void> _useAsCover(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    final message = AppLocalizations.of(context).coverChangedSnack;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(userAlbumRepositoryProvider).setCover(albumId, item.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _AlbumAction { rename, delete }
