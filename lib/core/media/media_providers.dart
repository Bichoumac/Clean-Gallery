import 'dart:async';

import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_providers.g.dart';

/// Number of items in the first query of a list.
///
/// The first chunk is shown immediately; the rest of the list follows in a
/// second query, so a 30,000-item timeline starts drawing at once.
const mediaChunkSize = 1000;

/// Smallest and largest grid column counts reachable by pinching.
const minGridColumns = 2;

/// See [minGridColumns].
const maxGridColumns = 6;

/// Current media access level, read without prompting.
@riverpod
Future<MediaAccess> mediaAccess(Ref ref) =>
    ref.watch(permissionServiceProvider).mediaAccess();

/// All items of a selection, read from the media index, trashed items
/// included.
///
/// When the index changes ([MediaIndexState.revision]), the list is
/// reloaded in place, without a loading state, so the grid keeps its scroll
/// position. Screens read [visibleMediaListProvider], which applies the
/// trash and pending favorite changes in memory.
@riverpod
class MediaList extends _$MediaList {
  /// Incremented by each load; older loads drop their result.
  var _generation = 0;

  @override
  Future<List<MediaItem>> build(MediaSelection selection) async {
    ref.listen(
      mediaIndexProvider.select((s) => s.revision),
      (_, _) => unawaited(_reload()),
    );
    final generation = ++_generation;
    final first = await ref
        .watch(mediaIndexRepositoryProvider)
        .load(selection, limit: mediaChunkSize);
    // A reload started meanwhile; it sets the newer list.
    if (generation != _generation) return state.value ?? first;
    if (first.length == mediaChunkSize) {
      unawaited(_loadRest(first, generation));
    }
    return first;
  }

  Future<void> _loadRest(List<MediaItem> first, int generation) async {
    final rest = await ref
        .read(mediaIndexRepositoryProvider)
        .load(selection, offset: first.length);
    if (!ref.mounted || generation != _generation) return;
    state = AsyncData([...first, ...rest]);
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    final items = await ref.read(mediaIndexRepositoryProvider).load(selection);
    if (!ref.mounted || generation != _generation) return;
    state = AsyncData(items);
  }
}

/// Ids of items deleted for good during this session.
///
/// Hidden by every list until the lists reload from the index, so an item
/// leaving the trash for good never shows again in between.
@Riverpod(keepAlive: true)
class DeletedIds extends _$DeletedIds {
  @override
  Set<String> build() => const {};

  /// Records [ids] as deleted.
  void add(Iterable<String> ids) => state = {...state, ...ids};
}

/// Favorite changes made in the app, by item id, applied before MediaStore
/// is reloaded. Lets the heart switch at once instead of after reloading
/// every list.
@Riverpod(keepAlive: true)
class FavoriteOverrides extends _$FavoriteOverrides {
  @override
  Map<String, bool> build() => const {};

  /// Records [favorite] for [ids].
  void set(Iterable<String> ids, {required bool favorite}) {
    state = {...state, for (final id in ids) id: favorite};
  }

  /// Forgets the changes for [ids], e.g. when the user declined them.
  void clear(Iterable<String> ids) {
    state = {...state}..removeWhere((id, _) => ids.contains(id));
  }
}

/// What screens show for a selection: [mediaListProvider] without trashed
/// or deleted items, with favorite changes applied. Loading and error
/// states are passed through, and each new chunk is applied as it arrives.
///
/// Computed in memory, so trashing, undoing or favoriting never queries the
/// index again; the order stays the same, which keeps viewer indexes in
/// sync with the grid. Until the first index is complete, an empty list
/// stays in the loading state.
@riverpod
AsyncValue<List<MediaItem>> visibleMediaList(
  Ref ref,
  MediaSelection selection,
) {
  final trashed = ref.watch(trashedIdsProvider).value ?? const <String>{};
  final deleted = ref.watch(deletedIdsProvider);
  final favorites = ref.watch(favoriteOverridesProvider);
  final ready = ref.watch(mediaIndexProvider.select((s) => s.ready));
  final onlyFavorites = selection.filter == MediaFilter.favorites;
  final list = ref.watch(mediaListProvider(selection));
  if (!ready && list is AsyncData<List<MediaItem>> && list.value.isEmpty) {
    return const AsyncLoading();
  }
  return list.whenData((items) {
    if (trashed.isEmpty && deleted.isEmpty && favorites.isEmpty) return items;
    final visible = <MediaItem>[];
    for (final item in items) {
      if (trashed.contains(item.id) || deleted.contains(item.id)) continue;
      final favorite = favorites[item.id];
      if (favorite == null) {
        visible.add(item);
      } else if (favorite || !onlyFavorites) {
        visible.add(item.copyWith(isFavorite: favorite));
      }
      // Unfavorited here: leaves the Favorites album at once.
    }
    return visible;
  });
}

/// Device folders that contain media, largest first, each with its newest
/// item as cover. Trashed items are neither counted nor used as covers.
@riverpod
Future<List<Album>> albums(Ref ref) {
  ref
    ..watch(trashedIdsProvider)
    ..watch(mediaIndexProvider.select((s) => s.revision));
  return ref.watch(mediaIndexRepositoryProvider).albums();
}

/// Number of items in a selection, without trashed items, for album tiles.
@riverpod
Future<int> mediaCount(Ref ref, MediaSelection selection) {
  ref
    ..watch(trashedIdsProvider)
    ..watch(mediaIndexProvider.select((s) => s.revision));
  return ref.watch(mediaIndexRepositoryProvider).count(selection);
}

/// Newest item of a selection, used as the album cover.
@riverpod
Future<MediaItem?> albumCover(Ref ref, MediaSelection selection) {
  ref
    ..watch(trashedIdsProvider)
    ..watch(mediaIndexProvider.select((s) => s.revision));
  return ref.watch(mediaIndexRepositoryProvider).newest(selection);
}

/// The selection a timeline currently shows: its base selection (a tab or an
/// album) plus the sort order and date range picked by the user.
///
/// One state per base selection. The sort order is saved in the settings
/// and restored at the next launch; the date range lasts for the session.
@Riverpod(keepAlive: true)
class ViewSelection extends _$ViewSelection {
  @override
  MediaSelection build(MediaSelection base) {
    // Read, not watch: other settings changes must not reset the view.
    final saved = ref.read(appSettingsControllerProvider).viewSorts;
    return base.copyWith(sort: saved[viewKey(base)] ?? base.sort);
  }

  /// Changes the sort order and saves it for this view.
  void setSort(MediaSort sort) {
    state = state.copyWith(sort: sort);
    unawaited(
      ref.read(appSettingsControllerProvider.notifier).setViewSort(base, sort),
    );
  }

  /// Limits the timeline to [dates], or shows all dates when `null`.
  void setDates(DateFilter? dates) => state = state.copyWith(dates: dates);

  /// Back to newest first, all dates.
  void reset() {
    setSort(base.sort);
    state = base;
  }
}

/// Column count of media grids, changed by pinching. Shared by all grids.
@Riverpod(keepAlive: true)
class GridColumns extends _$GridColumns {
  @override
  int build() => ref.read(appSettingsControllerProvider).defaultColumns;

  /// Sets the column count, e.g. when the default changes in Settings.
  void set(int columns) =>
      state = columns.clamp(minGridColumns, maxGridColumns);

  /// Pinch out: fewer, larger thumbnails.
  void zoomIn() => state = stepColumns(state, -1);

  /// Pinch in: more, smaller thumbnails.
  void zoomOut() => state = stepColumns(state, 1);
}

/// [columns] moved by [delta], kept within [minGridColumns]–[maxGridColumns].
int stepColumns(int columns, int delta) =>
    (columns + delta).clamp(minGridColumns, maxGridColumns);
