import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/location_scan.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/core/router/compact_nav_bar.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/trashed_item.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Albums tab: "All media" and "Favorites", then the device folders.
///
/// The Trash is a page of the app, not a MediaStore album. The Duplicates
/// virtual album joins the top row in M3.
///
/// Folders are sorted by size, or by the number of duplicates they hold
/// (for this session).
class AlbumsScreen extends ConsumerStatefulWidget {
  /// Creates the Albums tab.
  const AlbumsScreen({super.key});

  @override
  ConsumerState<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends ConsumerState<AlbumsScreen> {
  /// Whether folders with the most duplicates come first.
  bool _byDuplicates = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final duplicates = _byDuplicates
        ? ref.watch(folderDuplicateCountsProvider).value
        : null;
    var folders = ref.watch(albumsProvider).value ?? const <Album>[];
    if (duplicates != null) {
      // Folders with as many duplicates stay largest first.
      final order = {for (final (i, f) in folders.indexed) f.id: i};
      folders = [...folders]
        ..sort((a, b) {
          final byCount = (duplicates[b.id] ?? 0).compareTo(
            duplicates[a.id] ?? 0,
          );
          return byCount != 0 ? byCount : order[a.id]!.compareTo(order[b.id]!);
        });
    }
    final trash = ref.watch(trashItemsProvider).value ?? const <TrashedItem>[];
    final located = ref.watch(locatedMediaProvider).value;

    return RefreshIndicator(
      onRefresh: () => ref.read(mediaIndexProvider.notifier).sync(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              sliver: SliverToBoxAdapter(
                child: Text(l10n.navAlbums, style: textTheme.displaySmall),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _AlbumGrid(
              tiles: [
                _AlbumTile(
                  selection: MediaSelection.all,
                  name: l10n.albumsAllMedia,
                  location: AlbumRoutes.location(
                    AlbumRoutes.allKey,
                    l10n.albumsAllMedia,
                  ),
                ),
                _AlbumTile(
                  selection: MediaSelection.favorites,
                  name: l10n.albumsFavorites,
                  location: AlbumRoutes.location(
                    AlbumRoutes.favoritesKey,
                    l10n.albumsFavorites,
                  ),
                  icon: Icons.favorite_rounded,
                ),
                _AlbumTile(
                  name: l10n.mapTitle,
                  location: AppRoutes.map,
                  knownCount: located?.length,
                  knownCover: located?.firstOrNull?.item,
                  icon: Icons.map_rounded,
                ),
                _AlbumTile(
                  name: l10n.trashTitle,
                  location: AlbumRoutes.trash,
                  knownCount: trash.length,
                  knownCover: trash.firstOrNull?.item,
                  icon: Icons.delete_outline_rounded,
                ),
              ],
            ),
          ),
          if (folders.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.albumsFolders,
                          style: textTheme.titleLarge,
                        ),
                      ),
                    ),
                    PopupMenuButton<bool>(
                      tooltip: l10n.sortTitle,
                      icon: const Icon(Icons.sort_rounded),
                      initialValue: _byDuplicates,
                      onSelected: (value) =>
                          setState(() => _byDuplicates = value),
                      itemBuilder: (context) => [
                        CheckedPopupMenuItem(
                          value: false,
                          checked: !_byDuplicates,
                          child: Text(l10n.sortSize),
                        ),
                        CheckedPopupMenuItem(
                          value: true,
                          checked: _byDuplicates,
                          child: Text(l10n.sortDuplicates),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _AlbumGrid(
              tiles: [
                for (final album in folders)
                  _AlbumTile(
                    selection: album.selection,
                    name: album.name,
                    location: AlbumRoutes.location(album.id, album.name),
                    knownCount: album.count,
                    knownCover: album.cover,
                    duplicates: duplicates == null
                        ? null
                        : duplicates[album.id] ?? 0,
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: CompactNavBar.contentInset(context)),
          ),
        ],
      ),
    );
  }
}

class _AlbumGrid extends StatelessWidget {
  const _AlbumGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return SliverGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 12,
      childAspectRatio: 0.78,
      children: tiles,
    );
  }
}

/// Cover, name and item count of one album.
class _AlbumTile extends ConsumerWidget {
  const _AlbumTile({
    required this.name,
    required this.location,
    this.selection,
    this.knownCount,
    this.knownCover,
    this.icon,
    this.duplicates,
  });

  /// Number of items in a duplicate group, shown after the count when the
  /// folders are sorted by duplicates.
  final int? duplicates;

  final String name;

  /// Page opened by the tile.
  final String location;

  /// MediaStore selection to fetch the count and cover from when they are
  /// not given; `null` for albums that are not in MediaStore (Trash).
  final MediaSelection? selection;

  /// Count already known from the album list; fetched otherwise.
  final int? knownCount;

  /// Cover already known from the album list; fetched otherwise.
  final MediaItem? knownCover;

  /// Icon shown over the cover, for virtual albums.
  final IconData? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selection = this.selection;
    final cover =
        knownCover ??
        (selection == null
            ? null
            : ref.watch(albumCoverProvider(selection)).value);
    final count =
        knownCount ??
        (selection == null
            ? null
            : ref.watch(mediaCountProvider(selection)).value);

    return Semantics(
      button: true,
      label: [
        name,
        if (count != null) l10n.albumItemCount(count),
        if (duplicates case final n? when n > 0) l10n.albumDuplicateCount(n),
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push(location),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: theme.colorScheme.surfaceContainerHigh),
                    if (cover != null)
                      MediaThumbnail(item: cover, pixelSize: 512, hero: false),
                    if (icon != null)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(
                            icon,
                            size: 18,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (count != null)
              Text(
                [
                  l10n.albumItemCount(count),
                  if (duplicates case final n? when n > 0)
                    l10n.albumDuplicateCount(n),
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
