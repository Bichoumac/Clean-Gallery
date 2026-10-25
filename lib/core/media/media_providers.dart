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

/// All items of a selection, newest first, loaded in chunks.
///
/// The state grows as chunks arrive. Invalidate it to reload, e.g. on
/// pull-to-refresh.
@riverpod
class MediaList extends _$MediaList {
  @override
  Future<List<MediaItem>> build(MediaSelection selection) async {
    final source = ref.watch(mediaSourceProvider);
    // Rebuilt whenever the trash changes, so trashed items disappear.
    final hidden = await ref.watch(trashedIdsProvider.future);
    final total = await source.count(selection, hidden: hidden);
    final first = await source.load(
      selection,
      start: 0,
      end: math.min(mediaChunkSize, total),
      hidden: hidden,
    );
    if (total > mediaChunkSize) {
      unawaited(_loadRemaining(first, total, hidden));
    }
    return first;
  }

  Future<void> _loadRemaining(
    List<MediaItem> first,
    int total,
    Set<String> hidden,
  ) async {
    final source = ref.read(mediaSourceProvider);
    var items = first;
    for (var start = mediaChunkSize; start < total; start += mediaChunkSize) {
      final chunk = await source.load(
        selection,
        start: start,
        end: math.min(start + mediaChunkSize, total),
        hidden: hidden,
      );
      if (!ref.mounted) return;
      items = [...items, ...chunk];
      state = AsyncData(items);
    }
  }
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
