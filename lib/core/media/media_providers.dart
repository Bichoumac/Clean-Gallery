import 'dart:async';
import 'dart:math' as math;

import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_providers.g.dart';

/// Number of items requested from the media source per call.
///
/// The first chunk is shown immediately; the rest of the library streams in
/// behind it, so a 30,000-item timeline starts drawing in well under a
/// second.
const mediaChunkSize = 1000;

/// Smallest and largest grid column counts reachable by pinching.
const minGridColumns = 2;

/// See [minGridColumns].
const maxGridColumns = 6;

/// Current media access level, read without prompting.
@riverpod
Future<MediaAccess> mediaAccess(Ref ref) =>
    ref.watch(permissionServiceProvider).mediaAccess();

/// All items of a selection as MediaStore returns them, loaded in chunks.
///
/// The state grows as chunks arrive. Invalidate it to reload, e.g. on
/// pull-to-refresh. Screens read [visibleMediaListProvider], which applies
/// the trash and pending favorite changes in memory.
@riverpod
class MediaList extends _$MediaList {
  @override
  Future<List<MediaItem>> build(MediaSelection selection) async {
    final source = ref.watch(mediaSourceProvider);
    final total = await source.count(selection);
    final first = await source.load(
      selection,
      start: 0,
      end: math.min(mediaChunkSize, total),
    );
    if (total > mediaChunkSize) {
      unawaited(_loadRemaining(first, total));
    }
    return first;
  }

  Future<void> _loadRemaining(List<MediaItem> first, int total) async {
    final source = ref.read(mediaSourceProvider);
    var items = first;
    for (var start = mediaChunkSize; start < total; start += mediaChunkSize) {
      final chunk = await source.load(
        selection,
        start: start,
        end: math.min(start + mediaChunkSize, total),
      );
      if (!ref.mounted) return;
      items = [...items, ...chunk];
      state = AsyncData(items);
    }
  }
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
/// items, with favorite changes applied. Loading and error states are
/// passed through, and each new chunk is applied as it arrives.
///
/// Computed in memory, so trashing, undoing or favoriting never queries
/// MediaStore again; the order stays the same, which keeps viewer indexes in
/// sync with the grid.
@riverpod
AsyncValue<List<MediaItem>> visibleMediaList(
  Ref ref,
  MediaSelection selection,
) {
  final trashed = ref.watch(trashedIdsProvider).value ?? const <String>{};
  final favorites = ref.watch(favoriteOverridesProvider);
  final onlyFavorites = selection.filter == MediaFilter.favorites;
  return ref.watch(mediaListProvider(selection)).whenData((items) {
    if (trashed.isEmpty && favorites.isEmpty) return items;
    final visible = <MediaItem>[];
    for (final item in items) {
      if (trashed.contains(item.id)) continue;
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

/// Device folders that contain media, largest first.
@riverpod
Future<List<Album>> albums(Ref ref) async {
  final hidden = await ref.watch(trashedIdsProvider.future);
  return await ref.watch(mediaSourceProvider).albums(hidden: hidden);
}

/// Number of items in a selection, for album tiles.
@riverpod
Future<int> mediaCount(Ref ref, MediaSelection selection) async {
  final hidden = await ref.watch(trashedIdsProvider.future);
  return await ref.watch(mediaSourceProvider).count(selection, hidden: hidden);
}

/// Newest item of a selection, used as the album cover.
@riverpod
Future<MediaItem?> albumCover(Ref ref, MediaSelection selection) async {
  final hidden = await ref.watch(trashedIdsProvider.future);
  final items = await ref
      .watch(mediaSourceProvider)
      .load(selection, start: 0, end: 1, hidden: hidden);
  return items.firstOrNull;
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
