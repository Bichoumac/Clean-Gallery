import 'dart:async';

import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Asks which album to add [items] to, an existing one or a new one, adds
/// them and says so, with a button to open the album.
///
/// Only the album's list changes: the files stay where they are.
Future<void> addToAlbum(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  if (items.isEmpty) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final repository = ref.read(userAlbumRepositoryProvider);
  final ids = [for (final item in items) item.id];
  final containing = await repository.containing(ids);
  if (!context.mounted) return;
  final choice = await showModalBottomSheet<_AlbumChoice>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        _AddToAlbumSheet(count: items.length, containing: containing),
  );
  if (choice == null || !context.mounted) return;
  final UserAlbum? existing;
  final int albumId;
  final String name;
  switch (choice) {
    case _ExistingAlbum(:final album):
      existing = album;
      albumId = album.id;
      name = album.name;
    case _NewAlbum():
      existing = null;
      final typed = await askAlbumName(context, ref);
      if (typed == null) return;
      name = typed;
      albumId = await repository.create(typed);
  }
  final added = await repository.add(albumId, ids);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // With an action, it would stay until closed.
        persist: false,
        content: Text(
          added == 0 && existing != null
              ? l10n.alreadyInAlbumSnack(name)
              : l10n.addedToAlbumSnack(added, name),
        ),
        action: SnackBarAction(
          label: l10n.actionOpen,
          onPressed: () =>
              unawaited(router.push(AlbumRoutes.userAlbum(albumId))),
        ),
      ),
    );
}

/// Asks for the name of a new album, then creates it and opens it.
Future<void> createAlbum(BuildContext context, WidgetRef ref) async {
  final name = await askAlbumName(context, ref);
  if (name == null || !context.mounted) return;
  final id = await ref.read(userAlbumRepositoryProvider).create(name);
  if (context.mounted) unawaited(context.push(AlbumRoutes.userAlbum(id)));
}

/// Asks for an album name, starting from [initial] (renaming album
/// [renaming]). Returns the trimmed name, or `null` when cancelled.
///
/// An empty name, or one another album already has (ignoring case), is
/// refused in the dialog.
Future<String?> askAlbumName(
  BuildContext context,
  WidgetRef ref, {
  String initial = '',
  int? renaming,
}) {
  final taken = {
    for (final album in ref.read(userAlbumsProvider).value ?? <UserAlbum>[])
      if (album.id != renaming) album.name.toLowerCase(),
  };
  return showDialog<String>(
    context: context,
    builder: (context) => _AlbumNameDialog(
      initial: initial,
      taken: taken,
      renaming: renaming != null,
    ),
  );
}

/// What the user picked in the [_AddToAlbumSheet].
sealed class _AlbumChoice {
  const _AlbumChoice();
}

final class _NewAlbum extends _AlbumChoice {
  const _NewAlbum();
}

final class _ExistingAlbum extends _AlbumChoice {
  const _ExistingAlbum(this.album);

  final UserAlbum album;
}

/// *New album*, then the user's albums, each saying how many of the
/// [count] items it already holds ([containing], by album id).
class _AddToAlbumSheet extends ConsumerWidget {
  const _AddToAlbumSheet({required this.count, required this.containing});

  final int count;
  final Map<int, int> containing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final albums = ref.watch(userAlbumsProvider).value ?? const [];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                l10n.addToAlbumTitle(count),
                style: theme.textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: _Square(
                color: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.add_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(l10n.userAlbumNew),
              onTap: () => Navigator.pop(context, const _NewAlbum()),
            ),
            for (final album in albums)
              ListTile(
                leading: _Square(
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: album.cover == null
                      ? Icon(
                          Icons.photo_album_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : MediaThumbnail(
                          item: album.cover!,
                          pixelSize: 144,
                          hero: false,
                        ),
                ),
                title: Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(switch (containing[album.id] ?? 0) {
                  0 => l10n.albumItemCount(album.count),
                  final n when n >= count => l10n.addToAlbumAllIn,
                  final n => l10n.addToAlbumSomeIn(n),
                }),
                onTap: () => Navigator.pop(context, _ExistingAlbum(album)),
              ),
          ],
        ),
      ),
    );
  }
}

/// A 48 dp rounded square: an album cover in a list.
class _Square extends StatelessWidget {
  const _Square({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox.square(
      dimension: 48,
      child: ColoredBox(
        color: color,
        child: Center(child: child),
      ),
    ),
  );
}

class _AlbumNameDialog extends StatefulWidget {
  const _AlbumNameDialog({
    required this.initial,
    required this.taken,
    required this.renaming,
  });

  final String initial;

  /// Names of the other albums, lowercase.
  final Set<String> taken;

  final bool renaming;

  @override
  State<_AlbumNameDialog> createState() => _AlbumNameDialogState();
}

class _AlbumNameDialogState extends State<_AlbumNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  /// Error shown under the field once the user tried to confirm.
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final name = _controller.text.trim();
    final error = name.isEmpty
        ? l10n.userAlbumNameEmpty
        : widget.taken.contains(name.toLowerCase())
        ? l10n.userAlbumNameTaken
        : null;
    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.pop(context, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.renaming ? l10n.userAlbumRename : l10n.userAlbumNew),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: l10n.userAlbumNameLabel,
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.renaming ? l10n.actionRename : l10n.actionCreate),
        ),
      ],
    );
  }
}
