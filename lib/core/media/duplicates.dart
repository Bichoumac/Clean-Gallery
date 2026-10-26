import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/duplicate_group.dart';
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

/// Progress of the exact duplicate scan, see [DuplicateScan].
@freezed
abstract class DuplicateScanState with _$DuplicateScanState {
  /// Creates the state.
  const factory DuplicateScanState({
    /// Whether a scan is running.
    @Default(false) bool running,

    /// Items hashed during this scan.
    @Default(0) int hashed,

    /// Items to hash when this scan started.
    @Default(0) int toHash,

    /// Incremented each time the groups are rebuilt.
    @Default(0) int revision,
  }) = _DuplicateScanState;
}

/// Finds certain duplicates: hashes the content of items that share their
/// size with another item, then groups identical hashes (exact duplicates)
/// and shots of the same burst.
///
/// Incremental and resumable: hashes are saved after each batch and kept
/// until the file changes, so only new items are read. Run after each index
/// sync. See `docs/analysis-engine.md#exact-duplicates`.
@Riverpod(keepAlive: true)
class DuplicateScan extends _$DuplicateScan {
  Future<void>? _running;
  bool _again = false;

  @override
  DuplicateScanState build() => const DuplicateScanState();

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
  /// syncs the index and scans. The media are not touched.
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

    final toHash = await repository.pendingHashCount();
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
    if (ref.mounted) state = state.copyWith(revision: state.revision + 1);
  }
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
