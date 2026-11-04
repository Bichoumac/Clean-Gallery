import 'dart:async';
import 'dart:isolate';

import 'package:clean_gallery/analysis/photo_analysis.dart';
import 'package:clean_gallery/analysis/similarity.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/duplicate_group.dart';
import 'package:clean_gallery/domain/enums.dart';
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
/// perceptual hashes and quality: about a second of work on a phone, so that
/// [DuplicateScan.pause] takes effect quickly.
const perceptualBatchSize = 16;

/// Batches of thumbnails between two groupings of similar photos while the
/// scan runs, so groups show before the whole library is read.
const regroupEveryBatches = 60;

/// Side of the grayscale thumbnails perceptual hashes and quality are
/// computed on: 256 pixels, as blur shows better than at 128 (M4) and
/// MediaStore renders both from the same cached thumbnail.
const perceptualThumbnailSide = 256;

/// Runs CPU-heavy analysis work ([work]) away from the interface.
typedef AnalysisRunner = Future<R> Function<R>(FutureOr<R> Function() work);

/// Where the scan runs its hashing and grouping: a new isolate for each
/// call. App-level widget tests run them inline, since their fake clock
/// cannot wait for an isolate.
@Riverpod(keepAlive: true)
AnalysisRunner analysisRunner(Ref ref) => Isolate.run;

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
/// 2. similar photos: computes the perceptual hashes and the quality
///    (sharpness, brightness) of new photos from grayscale thumbnails, in
///    an isolate, then groups similar photos with the thresholds chosen in
///    Settings.
///
/// Incremental and resumable: hashes are saved after each batch and kept
/// until the file changes, so only new items are read. Similar photos are
/// regrouped every [regroupEveryBatches] batches, so the first groups show
/// long before a large library is read. Run after each index sync, and
/// again when the similarity thresholds change. See
/// `docs/analysis-engine.md#exact-duplicates` and
/// `docs/analysis-engine.md#similar-photos`.
@Riverpod(keepAlive: true)
class DuplicateScan extends _$DuplicateScan {
  Future<void>? _running;
  bool _again = false;
  int _pauses = 0;
  Completer<void>? _resumed;

  /// Holds the scan before its next batch until [resume] is called as many
  /// times. The viewer pauses it: MediaStore renders thumbnails almost one
  /// at a time, so the scan's would delay the photo being opened.
  void pause() {
    _pauses++;
    _resumed ??= Completer<void>();
  }

  /// Whether the scan is held by [pause].
  bool get paused => _pauses > 0;

  /// Undoes one [pause].
  void resume() {
    if (_pauses == 0) return;
    if (--_pauses == 0) {
      _resumed?.complete();
      _resumed = null;
    }
  }

  /// Waits while the scan is paused.
  Future<void> _unlessPaused() async {
    for (var resumed = _resumed; resumed != null; resumed = _resumed) {
      await resumed.future;
    }
  }

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
  /// similar photos again. The group goes away at once; the regrouping
  /// runs in the background, after any scan in progress.
  Future<void> ignore(DuplicateGroup group) async {
    final repository = ref.read(duplicateRepositoryProvider);
    await repository.ignorePairs([for (final item in group.items) item.id]);
    await repository.deleteGroup(group.id);
    if (!ref.mounted) return;
    state = state.copyWith(revision: state.revision + 1);
    unawaited(run());
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
    final runner = ref.read(analysisRunnerProvider);

    final toHash =
        await repository.pendingHashCount() +
        await repository.pendingPerceptualCount();
    if (!ref.mounted) return;
    state = state.copyWith(running: true, hashed: 0, toHash: toHash);
    while (true) {
      await _unlessPaused();
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

    var batches = 0;
    while (true) {
      await _unlessPaused();
      final batch = await repository.perceptualCandidates(
        limit: perceptualBatchSize,
      );
      if (batch.isEmpty || !ref.mounted) break;
      Map<String, GrayImage> images;
      try {
        images = await source.grayThumbnails(
          batch,
          side: perceptualThumbnailSide,
        );
      } on PlatformException catch (e) {
        if (e.code == 'permission') rethrow;
        // Saved without hashes, so one failing batch is not read again and
        // again: those photos are compared once their files change.
        images = const {};
      }
      final results = await _analyzeAll(images, runner);
      if (!ref.mounted) return;
      await repository.savePhotoAnalysis(batch, results);
      state = state.copyWith(hashed: state.hashed + batch.length);
      if (++batches % regroupEveryBatches == 0) {
        await _regroup(runner);
        if (!ref.mounted) return;
      }
    }
    await _regroup(runner);
  }

  /// Groups the photos hashed so far into similar photos, with the
  /// thresholds chosen in Settings.
  Future<void> _regroup(AnalysisRunner runner) async {
    final repository = ref.read(duplicateRepositoryProvider);
    final thresholds = ref
        .read(appSettingsControllerProvider)
        .similarityThresholds;
    final groups = await _group(
      runner,
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

/// Hashes and quality of [images], by id, computed by [runner] (in an
/// isolate) so the interface never waits on the DCT.
Future<Map<String, PhotoAnalysis>> _analyzeAll(
  Map<String, GrayImage> images,
  AnalysisRunner runner,
) async {
  if (images.isEmpty) return const {};
  return await runner(
    () => {
      for (final MapEntry(:key, :value) in images.entries)
        key: analyzePhoto(value),
    },
  );
}

/// [findSimilarGroups] run by [runner] (in an isolate): with tens of
/// thousands of photos, the search takes longer than a frame.
Future<List<SimilarGroup>> _group(
  AnalysisRunner runner,
  List<HashedPhoto> photos,
  SimilarityThresholds thresholds, {
  required Set<(int, int)> ignored,
  required Map<int, int> certainGroup,
}) async {
  if (photos.length < 2) return const [];
  return await runner(
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

/// The group each item of [groups] belongs to, by item id. An item in a
/// certain group (copies, burst) and a similar group gets its certain
/// group.
Map<String, DuplicateGroup> groupsByItem(List<DuplicateGroup> groups) => {
  for (final group in groups)
    if (group.kind == DuplicateKind.similar)
      for (final item in group.items) item.id: group,
  for (final group in groups)
    if (group.kind != DuplicateKind.similar)
      for (final item in group.items) item.id: group,
};

/// The duplicate group of every item of the library, by item id, see
/// [groupsByItem]. Used by the viewer's group strip.
@riverpod
Future<Map<String, DuplicateGroup>> libraryGroupsByItem(Ref ref) async =>
    groupsByItem(
      await ref.watch(duplicateGroupsProvider(MediaSelection.all).future),
    );

/// Number of items in a duplicate group in each folder, by folder id, for
/// the Albums tab sorted by duplicates.
@riverpod
Future<Map<String, int>> folderDuplicateCounts(Ref ref) {
  ref
    ..watch(trashedIdsProvider)
    ..watch(mediaIndexProvider.select((s) => s.revision))
    ..watch(duplicateScanProvider.select((s) => s.revision));
  return ref.watch(mediaIndexRepositoryProvider).duplicateCountsByFolder();
}

/// The part of a timeline's selection that duplicates are looked for in:
/// its filter and folder.
MediaSelection duplicateScope(MediaSelection selection) =>
    MediaSelection(filter: selection.filter, albumId: selection.albumId);
