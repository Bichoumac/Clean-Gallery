import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/duplicate_group.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/trashed_item.dart';
import 'package:clean_gallery/features/cleanup/cleanup_lists.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_summary.g.dart';

/// Items of one cleanup category and the space they take.
typedef StorageShare = ({int count, int bytes});

/// What the Stats tab's dashboard shows: the space the library takes and
/// the space each cleanup category could free. See
/// `docs/features/stats.md`.
final class StorageSummary {
  /// Creates a summary.
  const StorageSummary({
    required this.totals,
    required this.exact,
    required this.burst,
    required this.similar,
    required this.screenshots,
    required this.largeVideos,
    required this.poorQuality,
    required this.trash,
  });

  /// Photos and videos outside the trash.
  final MediaTotals totals;

  /// Items suggested for the trash among identical copies.
  final StorageShare exact;

  /// Items suggested for the trash among burst shots, those already counted
  /// in [exact] left out.
  final StorageShare burst;

  /// Items suggested for the trash among similar photos, those already
  /// counted in [exact] or [burst] left out.
  final StorageShare similar;

  /// Old screenshots, those already counted above left out.
  final StorageShare screenshots;

  /// Large videos, those already counted above left out.
  final StorageShare largeVideos;

  /// Blurry or very dark photos, those already counted above left out.
  final StorageShare poorQuality;

  /// Items in the app trash, freed when it is emptied.
  final StorageShare trash;

  /// Space taken by photos and videos outside the trash.
  int get usedBytes => totals.photoBytes + totals.videoBytes;

  /// Space that cleaning could free: every category and the trash.
  int get reclaimableBytes =>
      exact.bytes +
      burst.bytes +
      similar.bytes +
      screenshots.bytes +
      largeVideos.bytes +
      poorQuality.bytes +
      trash.bytes;
}

/// The summary of [totals], duplicate [groups] of the whole library, old
/// [screenshots], [largeVideos], [poorQuality] photos and [trashed] items.
/// Each item is counted once, in the first category it belongs to:
/// identical copies, bursts, similar photos, screenshots, large videos,
/// blurry photos.
StorageSummary summarize({
  required MediaTotals totals,
  required List<DuplicateGroup> groups,
  required List<TrashedItem> trashed,
  List<MediaItem> screenshots = const [],
  List<MediaItem> largeVideos = const [],
  List<MediaItem> poorQuality = const [],
}) {
  final extras = {
    for (final kind in DuplicateKind.values) kind: <String, MediaItem>{},
  };
  for (final group in groups) {
    for (final item in group.extras) {
      extras[group.kind]![item.id] = item;
    }
  }
  final counted = <String>{};
  StorageShare share(Iterable<MediaItem> items) {
    final fresh = {
      for (final item in items)
        if (!counted.contains(item.id)) item.id: item,
    };
    counted.addAll(fresh.keys);
    return _share(fresh.values);
  }

  return StorageSummary(
    totals: totals,
    exact: share(extras[DuplicateKind.exact]!.values),
    burst: share(extras[DuplicateKind.burst]!.values),
    similar: share(extras[DuplicateKind.similar]!.values),
    screenshots: share(screenshots),
    largeVideos: share(largeVideos),
    poorQuality: share(poorQuality),
    trash: _share([for (final entry in trashed) entry.item]),
  );
}

StorageShare _share(Iterable<MediaItem> items) => (
  count: items.length,
  bytes: items.fold(0, (sum, item) => sum + item.sizeBytes),
);

/// The dashboard's summary, updated after each sync, scan and trash
/// change.
@riverpod
Future<StorageSummary> storageSummary(Ref ref) async {
  ref.watch(mediaIndexProvider.select((s) => s.revision));
  final trashed = await ref.watch(trashItemsProvider.future);
  final groups = await ref.watch(
    duplicateGroupsProvider(duplicateScope(MediaSelection.all)).future,
  );
  final repository = ref.watch(mediaIndexRepositoryProvider);
  final trashedIds = {for (final entry in trashed) entry.item.id};
  Future<List<MediaItem>> outsideTrash(CleanupList list) async => [
    for (final item in await repository.load(
      ref.watch(cleanupSelectionProvider(list)),
    ))
      if (!trashedIds.contains(item.id)) item,
  ];

  return summarize(
    totals: await repository.totals(),
    groups: groups,
    trashed: trashed,
    screenshots: await outsideTrash(CleanupList.screenshots),
    largeVideos: await outsideTrash(CleanupList.largeVideos),
    poorQuality: await outsideTrash(CleanupList.poorQuality),
  );
}
