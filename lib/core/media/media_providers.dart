import 'dart:async';
import 'dart:math' as math;

import 'package:clean_gallery/core/providers.dart';
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

/// Device folders that contain media, largest first.
@riverpod
Future<List<Album>> albums(Ref ref) => ref.watch(mediaSourceProvider).albums();

/// Number of items in a selection, for album tiles.
@riverpod
Future<int> mediaCount(Ref ref, MediaSelection selection) =>
    ref.watch(mediaSourceProvider).count(selection);

/// Newest item of a selection, used as the album cover.
@riverpod
Future<MediaItem?> albumCover(Ref ref, MediaSelection selection) async {
  final items = await ref
      .watch(mediaSourceProvider)
      .load(selection, start: 0, end: 1);
  return items.firstOrNull;
}

/// Column count of media grids, changed by pinching. Shared by all grids.
@Riverpod(keepAlive: true)
class GridColumns extends _$GridColumns {
  @override
  int build() => 4;

  /// Pinch out: fewer, larger thumbnails.
  void zoomIn() => state = stepColumns(state, -1);

  /// Pinch in: more, smaller thumbnails.
  void zoomOut() => state = stepColumns(state, 1);
}

/// [columns] moved by [delta], kept within [minGridColumns]–[maxGridColumns].
int stepColumns(int columns, int delta) =>
    (columns + delta).clamp(minGridColumns, maxGridColumns);
