import 'dart:isolate';

import 'package:clean_gallery/analysis/perceptual_hash.dart';
import 'package:clean_gallery/analysis/similarity.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/duplicate_group.dart';
import 'package:clean_gallery/domain/gray_image.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'duplicates.freezed.dart';
part 'duplicates.g.dart';

/// Items hashed per call to the media source. Each one is read in full, so
/// batches stay small and progress is saved often.
const hashBatchSize = 20;

/// Photos whose thumbnails are read per call to the media source, for
/// perceptual hashes. Thumbnails are small, so batches are larger.
const perceptualBatchSize = 40;

/// Side of the grayscale thumbnails perceptual hashes are computed on.
const perceptualThumbnailSide = 128;

/// Progress of the duplicate scan, see [DuplicateScan].
@freezed
abstract class DuplicateScanState with _$DuplicateScanState {
  /// Creates the state.
  const factory DuplicateScanState({
    /// Whether a scan is running.
    @Default(false) bool running,

    /// Items hashed during this scan, content and perceptual hashes
    /// together.
    @Default(0) int hashed,

    /// Items to hash when this scan started.
    @Default(0) int toHash,

    /// Incremented each time the groups are rebuilt.
    @Default(0) int revision,
  }) = _DuplicateScanState;
}

/// Finds duplicates, in two passes:
///
/// 1. certain duplicates: hashes the content of items that share their
///    size with another item, then groups identical hashes (exact
///    duplicates) and shots of the same burst;
/// 2. similar photos: computes the perceptual hashes of new photos from
///    grayscale thumbnails, in an isolate, then groups similar photos with
///    the thresholds chosen in Settings.
///
/// Incremental and resumable: hashes are saved after each batch and kept
/// until the file changes, so only new items are read. Run after each index
/// sync, and again when the similarity thresholds change. See
/// `docs/analysis-engine.md#exact-duplicates` and
/// `docs/analysis-engine.md#similar-photos`.
@Riverpod(keepAlive: true)
class DuplicateScan extends _$DuplicateScan {
  Future<void>? _running;
  bool _again = false;

  @override
  DuplicateScanState build() {
    // New thresholds only regroup: hashes are kept.
    ref.listen(
      appSettingsControllerProvider.select((s) => s.similarityThresholds),
      (_, _) => run(),
    );
    return const DuplicateScanState();
  }

  /// Marks the items of [group] "Not duplicates": they are never grouped as
  /// similar photos again. Regroups at once.
  Future<void> ignore(DuplicateGroup group) async {
    await ref.read(duplicateRepositoryProvider).ignorePairs([
      for (final item in group.items) item.id,
    ]);
    if (ref.mounted) await run();
  }

  /// Hashes what is new and rebuilds the groups. A call made while a scan
  /// runs schedules one more pass. Platform errors stop the scan; hashes
  /// saved so far are kept.
  Future<void> run() {
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = _runLoop();
  }

  /// Works out every analysis result again (Settings → "Analyze the
  /// library again"): forgets dates, burst ids, hashes and groups, then
  /// syncs the index and scans. The media and the pairs marked "Not
  /// duplicates" are kept.
  Future<void> reanalyze() async {
    await ref.read(mediaIndexRepositoryProvider).resetAnalysis();
    if (!ref.mounted) return;
    await ref.read(mediaIndexProvider.notifier).sync();
    if (ref.mounted) await run();
  }

  Future<void> _runLoop() async {
    try {
      do {
        _again = false;
        await _runOnce();
      } while (_again && ref.mounted);
    } on PlatformException {
      // Keep what was hashed; the next scan resumes.
    } finally {
      _running = null;
      if (ref.mounted) state = state.copyWith(running: false);
    }
  }

  Future<void> _runOnce() async {
    final access = await ref.read(permissionServiceProvider).mediaAccess();
    if (access == MediaAccess.denied || !ref.mounted) return;
    final repository = ref.read(duplicateRepositoryProvider);
    final source = ref.read(mediaSourceProvider);

    final toHash =
        await repository.pendingHashCount() +
        await repository.pendingPerceptualCount();
    if (!ref.mounted) return;
    state = state.copyWith(running: true, hashed: 0, toHash: toHash);
    while (true) {
      final batch = await repository.hashCandidates(limit: hashBatchSize);
      if (batch.isEmpty || !ref.mounted) break;
      final hashes = await source.contentHashes(batch);
      if (!ref.mounted) return;
      await repository.saveHashes(batch, hashes);
      state = state.copyWith(hashed: state.hashed + batch.length);
    }
    await repository.rebuildGroups();
    // Certain duplicates show while similar photos are worked out.
    if (!ref.mounted) return;
    state = state.copyWith(revision: state.revision + 1);

    while (true) {
      final batch = await repository.perceptualCandidates(
        limit: perceptualBatchSize,
      );
      if (batch.isEmpty || !ref.mounted) break;
      final images = await source.grayThumbnails(
        batch,
        side: perceptualThumbnailSide,
      );
      final hashes = await _hashInIsolate(images);
      if (!ref.mounted) return;
      await repository.savePerceptualHashes(batch, hashes);
      state = state.copyWith(hashed: state.hashed + batch.length);
    }
    final thresholds = ref
        .read(appSettingsControllerProvider)
        .similarityThresholds;
    final groups = await _groupInIsolate(
      await repository.hashedPhotos(),
      thresholds,
      ignored: await repository.ignoredPairs(),
      certainGroup: await repository.certainGroups(),
    );
    if (!ref.mounted) return;
    await repository.replaceSimilarGroups(groups);
    if (ref.mounted) state = state.copyWith(revision: state.revision + 1);
  }
}

/// Perceptual hashes of [images], by id, computed in an isolate so the
/// interface never waits on the DCT.
Future<Map<String, PerceptualHashes>> _hashInIsolate(
  Map<String, GrayImage> images,
) async {
  if (images.isEmpty) return const {};
  return await Isolate.run(
    () => {
      for (final MapEntry(:key, :value) in images.entries)
        key: perceptualHashes(value),
    },
  );
}

/// [findSimilarGroups] in an isolate: with tens of thousands of photos,
/// the search takes longer than a frame.
Future<List<SimilarGroup>> _groupInIsolate(
  List<HashedPhoto> photos,
  SimilarityThresholds thresholds, {
  required Set<(int, int)> ignored,
  required Map<int, int> certainGroup,
}) async {
  if (photos.length < 2) return const [];
  return await Isolate.run(
    () => findSimilarGroups(
      photos,
      thresholds,
      ignored: ignored,
      certainGroup: certainGroup,
    ),
  );
}

/// Duplicate groups among the items of [base] (its filter and folder; sort
/// and dates are ignored), without trashed items, newest first.
@riverpod
Future<List<DuplicateGroup>> duplicateGroups(Ref ref, MediaSelection base) {
  ref
    ..watch(trashedIdsProvider)
    ..watch(mediaIndexProvider.select((s) => s.revision))
    ..watch(duplicateScanProvider.select((s) => s.revision));
  return ref
      .watch(mediaIndexRepositoryProvider)
      .duplicateGroups(duplicateScope(base));
}

/// The part of a timeline's selection that duplicates are looked for in:
/// its filter and folder.
MediaSelection duplicateScope(MediaSelection selection) =>
    MediaSelection(filter: selection.filter, albumId: selection.albumId);
