import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/duplicate_group.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/trashed_item.dart';
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

  /// Items in the app trash, freed when it is emptied.
  final StorageShare trash;

  /// Space taken by photos and videos outside the trash.
  int get usedBytes => totals.photoBytes + totals.videoBytes;

  /// Space that cleaning could free: duplicates, similar photos and the
  /// trash.
  int get reclaimableBytes =>
      exact.bytes + burst.bytes + similar.bytes + trash.bytes;
}

/// The summary of [totals], duplicate [groups] of the whole library and
/// [trashed] items. Each item is counted once, in the first of identical
/// copies, bursts and similar photos it is an extra of.
StorageSummary summarize({
  required MediaTotals totals,
  required List<DuplicateGroup> groups,
  required List<TrashedItem> trashed,
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
  StorageShare share(DuplicateKind kind) {
    final items = extras[kind]!..removeWhere((id, _) => counted.contains(id));
    counted.addAll(items.keys);
    return _share(items.values);
  }

  return StorageSummary(
    totals: totals,
    exact: share(DuplicateKind.exact),
    burst: share(DuplicateKind.burst),
    similar: share(DuplicateKind.similar),
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
  final totals = await ref.watch(mediaIndexRepositoryProvider).totals();
  return summarize(totals: totals, groups: groups, trashed: trashed);
}
