import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/duplicate_group.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Side of a thumbnail of the strip, in logical pixels.
const _thumbSide = 56.0;

/// The duplicate group of the photo shown in the viewer, at the bottom of
/// the screen: its thumbnails in a row that scrolls sideways, the suggested
/// one marked *Best*, and large *Trash* and *Keep* buttons to sort the
/// group one photo at a time.
///
/// Items trashed from the strip stay in it, dimmed, so the group can be
/// sorted to the end; tapping one restores it. Kept items get a check.
class GroupStrip extends ConsumerWidget {
  /// Creates the strip of [group], [current] being the photo shown.
  const GroupStrip({
    required this.group,
    required this.current,
    required this.kept,
    required this.trashed,
    required this.onOpen,
    required this.onRestore,
    required this.onKeep,
    required this.onTrash,
    required this.onUndo,
    super.key,
  });

  /// The group, as when the viewer reached it.
  final DuplicateGroup group;

  /// Id of the item shown.
  final String current;

  /// Ids marked Keep during this visit.
  final Set<String> kept;

  /// Ids moved to the trash from the strip during this visit.
  final Set<String> trashed;

  /// Shows `item` in the viewer.
  final ValueChanged<MediaItem> onOpen;

  /// Takes `item` back from the trash.
  final ValueChanged<MediaItem> onRestore;

  /// Keeps the item shown and goes to the next one to sort; `null` when
  /// the item shown is not in the group.
  final VoidCallback? onKeep;

  /// Moves the item shown to the trash and goes to the next one to sort;
  /// `null` when the item shown is not in the group.
  final VoidCallback? onTrash;

  /// Restores the last item trashed from the strip, or `null` when there
  /// is none.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final source = ref.watch(mediaSourceProvider);
    final onUndo = this.onUndo;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 32, bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l10n.viewerGroupTitle(group.items.length),
                  style: textTheme.labelLarge?.copyWith(color: Colors.white70),
                ),
              ),
              SizedBox(
                height: _thumbSide + 20,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: group.items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final item = group.items[i];
                    final isTrashed = trashed.contains(item.id);
                    final selected = item.id == current;
                    return _Thumb(
                      image: source.thumbnail(item, size: 192),
                      selected: selected,
                      best: item.id == group.best.id,
                      kept: kept.contains(item.id),
                      trashed: isTrashed,
                      label: [
                        if (item.id == group.best.id) l10n.duplicatesBest,
                        if (kept.contains(item.id)) l10n.swipeKeep,
                        if (isTrashed) l10n.viewerGroupTrashed,
                      ].join(', '),
                      onTap: () => isTrashed ? onRestore(item) : onOpen(item),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (onUndo != null) ...[
                      IconButton.filledTonal(
                        tooltip: l10n.actionUndo,
                        onPressed: onUndo,
                        icon: const Icon(Icons.undo_rounded),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: onTrash,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(l10n.viewerGroupTrash),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                        ),
                        onPressed: onKeep,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(l10n.swipeKeep),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One thumbnail of the strip: a lime frame when shown, a *Best* pill on
/// the suggested one, a check when kept, dimmed with a trash icon when
/// trashed.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.image,
    required this.selected,
    required this.best,
    required this.kept,
    required this.trashed,
    required this.label,
    required this.onTap,
  });

  final ImageProvider image;
  final bool selected;
  final bool best;
  final bool kept;
  final bool trashed;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label.isEmpty ? l10n.viewerGroupPhoto : label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: _thumbSide,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _thumbSide,
                height: _thumbSide,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? colors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        opacity: trashed ? 0.35 : 1,
                        child: Image(
                          image: image,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(color: Colors.white12),
                        ),
                      ),
                      if (trashed)
                        const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        )
                      else if (kept)
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: CircleAvatar(
                              radius: 9,
                              backgroundColor: colors.primary,
                              child: Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: colors.onPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (best)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      l10n.duplicatesBest,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
