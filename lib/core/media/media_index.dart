import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_index.freezed.dart';
part 'media_index.g.dart';

/// Items described per call to the media source while syncing.
const indexChunkSize = 1000;

/// Longest time lists wait for new rows while a sync writes many of them.
const indexRefreshInterval = Duration(seconds: 1);

/// State of the media index, see [MediaIndex].
@freezed
abstract class MediaIndexState with _$MediaIndexState {
  /// Creates the state.
  const factory MediaIndexState({
    /// Whether the index was complete at least once. Until then an empty
    /// list means "not indexed yet", not "no media".
    @Default(false) bool ready,

    /// Whether a sync is running.
    @Default(false) bool syncing,

    /// Incremented each time indexed rows change; lists reload when it does.
    @Default(0) int revision,
  }) = _MediaIndexState;
}

/// Keeps the media index (the `assets` table) in sync with the device.
///
/// Lists read the index, so they show at once at launch; [sync] then
/// applies what changed since the last launch. A sync asks the media source
/// for the id and revision of every item, compares them with the database,
/// describes only new and changed items and removes the missing ones. See
/// `docs/features/library.md#media-index`.
@Riverpod(keepAlive: true)
class MediaIndex extends _$MediaIndex {
  Future<void>? _running;
  bool _again = false;

  @override
  MediaIndexState build() => MediaIndexState(
    ready: ref.read(appSettingsControllerProvider).mediaIndexVersion != null,
  );

  /// Brings the index up to date with the device.
  ///
  /// Called at launch, when the app returns to the foreground and on
  /// pull-to-refresh. A call made while a sync runs schedules one more pass
  /// and completes with it. Platform errors (e.g. a revoked permission)
  /// stop the sync and keep the index as it is.
  Future<void> sync() {
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = _syncLoop();
  }

  /// Tells lists that indexed rows changed outside a sync, e.g. after a
  /// favorite or a permanent deletion.
  void changed() => state = state.copyWith(revision: state.revision + 1);

  Future<void> _syncLoop() async {
    state = state.copyWith(syncing: true);
    try {
      do {
        _again = false;
        await _syncOnce();
      } while (_again && ref.mounted);
    } on PlatformException {
      // Keep the index as it is; the next sync tries again.
    } finally {
      _running = null;
      if (ref.mounted) state = state.copyWith(syncing: false);
    }
  }

  Future<void> _syncOnce() async {
    final access = await ref.read(permissionServiceProvider).mediaAccess();
    if (access == MediaAccess.denied || !ref.mounted) return;
    final source = ref.read(mediaSourceProvider);
    final repository = ref.read(mediaIndexRepositoryProvider);
    final indexedVersion = ref
        .read(appSettingsControllerProvider)
        .mediaIndexVersion;

    final snapshot = await source.snapshot();
    final plan = planIndexSync(
      indexed: await repository.revisions(),
      current: snapshot.revisions,
      // The platform rebuilt its database: ids may now be other files.
      refreshAll: indexedVersion != null && indexedVersion != snapshot.version,
    );
    if (!ref.mounted) return;

    if (plan.removed.isNotEmpty) {
      await repository.remove(
        plan.removed,
        keepTrashed: access == MediaAccess.limited,
      );
      changed();
    }
    final sinceRefresh = Stopwatch()..start();
    for (var start = 0; start < plan.changed.length; start += indexChunkSize) {
      final ids = plan.changed.sublist(
        start,
        (start + indexChunkSize).clamp(0, plan.changed.length),
      );
      final entries = await source.describe(ids);
      if (!ref.mounted) return;
      await repository.upsert(entries, resetAnalysis: plan.refreshAll);
      // The first rows show at once on a first launch, then lists are
      // refreshed about once a second rather than after every chunk.
      final last = start + indexChunkSize >= plan.changed.length;
      if (start == 0 || last || sinceRefresh.elapsed >= indexRefreshInterval) {
        changed();
        sinceRefresh.reset();
      }
    }

    if (indexedVersion != snapshot.version) {
      await ref
          .read(appSettingsControllerProvider.notifier)
          .setMediaIndexVersion(snapshot.version);
    }
    if (ref.mounted && !state.ready) state = state.copyWith(ready: true);
  }
}

/// What a sync must do, from [planIndexSync].
typedef IndexSyncPlan = ({
  /// Ids to describe and write, in the order of the snapshot (newest
  /// first), so the top of the timelines fills first.
  List<String> changed,

  /// Indexed ids that are no longer on the device.
  List<int> removed,

  /// Whether every item is described again.
  bool refreshAll,
});

/// Compares the [indexed] revisions (by id; `null` when never indexed) with
/// the [current] ones of the device, newest first.
///
/// New items and items whose revision changed are to be described; with
/// [refreshAll], every current item is.
IndexSyncPlan planIndexSync({
  required Map<int, int?> indexed,
  required Map<String, int> current,
  bool refreshAll = false,
}) {
  final changed = <String>[];
  final seen = <int>{};
  for (final MapEntry(key: id, value: revision) in current.entries) {
    final key = int.tryParse(id);
    if (key == null) continue;
    seen.add(key);
    if (refreshAll || indexed[key] != revision) changed.add(id);
  }
  return (
    changed: changed,
    removed: [
      for (final id in indexed.keys)
        if (!seen.contains(id)) id,
    ],
    refreshAll: refreshAll,
  );
}
