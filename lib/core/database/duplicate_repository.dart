import 'package:clean_gallery/analysis/analysis_version.dart';
import 'package:clean_gallery/analysis/best_picker.dart';
import 'package:clean_gallery/analysis/photo_analysis.dart';
import 'package:clean_gallery/analysis/similarity.dart';
import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:drift/drift.dart';

/// Content hash stored for an item that could not be read, so it is not
/// tried again until its file changes. Never grouped.
const unreadableHash = '';

/// Writes of the duplicate detection: content and perceptual hashes in
/// `assets`, the groups in `duplicate_groups` and `duplicate_members`, and
/// the pairs the user marked "Not duplicates" in `ignored_pairs`.
///
/// Reads for screens are in `MediaIndexRepository.duplicateGroups`. See
/// `docs/analysis-engine.md#exact-duplicates` and
/// `docs/analysis-engine.md#similar-photos`.
final class DuplicateRepository {
  /// Creates the repository on [_db].
  const DuplicateRepository(this._db);

  final AppDatabase _db;

  /// Condition on `assets` (aliased `a`) selecting items that may have an
  /// exact duplicate but no hash yet: their size is shared by another item.
  static const _candidate =
      'a.content_hash IS NULL AND a.size_bytes > 0 '
      'AND a.id NOT IN (SELECT asset_id FROM trash_entries) '
      'AND a.size_bytes IN (SELECT size_bytes FROM assets '
      'WHERE size_bytes > 0 GROUP BY size_bytes HAVING COUNT(*) > 1)';

  /// Condition on `assets` (aliased `a`) selecting photos whose perceptual
  /// hashes were not computed by the current [analysisVersion].
  static const _perceptualCandidate =
      "a.kind = 'photo' AND a.analysis_version < $analysisVersion "
      'AND a.id NOT IN (SELECT asset_id FROM trash_entries)';

  /// Up to [limit] items to hash, smallest files first so progress shows
  /// early. Trashed items are skipped.
  Future<List<MediaItem>> hashCandidates({required int limit}) async {
    final rows = await _db
        .customSelect(
          'SELECT a.* FROM assets a WHERE $_candidate '
          'ORDER BY a.size_bytes, a.id LIMIT ?',
          variables: [Variable.withInt(limit)],
          readsFrom: {_db.assets, _db.trashEntries},
        )
        .get();
    return [for (final row in rows) _db.assets.map(row.data).toMediaItem()];
  }

  /// Number of items still to hash.
  Future<int> pendingHashCount() async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM assets a WHERE $_candidate',
          readsFrom: {_db.assets, _db.trashEntries},
        )
        .getSingle();
    return row.read<int>('n');
  }

  /// Stores the content [hashes] of [items], by id. Items missing from
  /// [hashes] could not be read and get [unreadableHash].
  Future<void> saveHashes(List<MediaItem> items, Map<String, String> hashes) =>
      _db.batch((batch) {
        for (final item in items) {
          batch.update(
            _db.assets,
            AssetsCompanion(
              contentHash: Value(hashes[item.id] ?? unreadableHash),
            ),
            where: (t) => t.id.equals(int.parse(item.id)),
          );
        }
      });

  /// Up to [limit] photos whose perceptual hashes are to compute, newest
  /// first so recent photos are compared first. Trashed items are skipped.
  Future<List<MediaItem>> perceptualCandidates({required int limit}) async {
    final rows = await _db
        .customSelect(
          'SELECT a.* FROM assets a WHERE $_perceptualCandidate '
          'ORDER BY COALESCE(a.capture_at, a.taken_at) DESC, a.id DESC '
          'LIMIT ?',
          variables: [Variable.withInt(limit)],
          readsFrom: {_db.assets, _db.trashEntries},
        )
        .get();
    return [for (final row in rows) _db.assets.map(row.data).toMediaItem()];
  }

  /// Number of photos whose perceptual hashes are to compute.
  Future<int> pendingPerceptualCount() async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM assets a WHERE $_perceptualCandidate',
          readsFrom: {_db.assets, _db.trashEntries},
        )
        .getSingle();
    return row.read<int>('n');
  }

  /// Stores the perceptual hashes and quality of [photos] from [results],
  /// by id, and marks them analysed by the current [analysisVersion].
  /// Photos missing from [results] had no readable thumbnail: they keep no
  /// hash and no quality, so they are neither compared nor offered as
  /// blurry, until their file changes.
  Future<void> savePhotoAnalysis(
    List<MediaItem> photos,
    Map<String, PhotoAnalysis> results,
  ) => _db.batch((batch) {
    for (final photo in photos) {
      final result = results[photo.id];
      batch.update(
        _db.assets,
        AssetsCompanion(
          dHash: Value(result?.hashes.dHash),
          pHash: Value(result?.hashes.pHash),
          blurScore: Value(result?.quality.sharpness),
          brightness: Value(result?.quality.brightness),
          analysisVersion: const Value(analysisVersion),
        ),
        where: (t) => t.id.equals(int.parse(photo.id)),
      );
    }
  });

  /// Every photo with perceptual hashes, trashed ones included, dated by
  /// its resolved capture date when known.
  Future<List<HashedPhoto>> hashedPhotos() async {
    final a = _db.assets;
    final query = _db.selectOnly(a)
      ..addColumns([
        a.id,
        a.dHash,
        a.pHash,
        a.width,
        a.height,
        a.captureAt,
        a.takenAt,
        a.cameraModel,
        a.latitude,
        a.longitude,
      ])
      ..where(a.kind.equalsValue(MediaKind.photo) & a.pHash.isNotNull());
    return [
      for (final row in await query.get())
        HashedPhoto(
          id: row.read(a.id)!,
          hashes: (dHash: row.read(a.dHash) ?? 0, pHash: row.read(a.pHash)!),
          width: row.read(a.width)!,
          height: row.read(a.height)!,
          takenAt: row.read(a.captureAt) ?? row.read(a.takenAt)!,
          cameraModel: row.read(a.cameraModel),
          latitude: row.read(a.latitude),
          longitude: row.read(a.longitude),
        ),
    ];
  }

  /// Pairs the user marked "Not duplicates", as `(a, b)` with `a < b`.
  Future<Set<(int, int)>> ignoredPairs() async => {
    for (final row in await _db.select(_db.ignoredPairs).get())
      (row.assetA, row.assetB),
  };

  /// Marks every pair of the items with [ids] "Not duplicates": they are
  /// never grouped as similar photos again.
  Future<void> ignorePairs(List<String> ids) {
    final keys = [for (final id in ids) int.parse(id)]..sort();
    return _db.batch((batch) {
      for (var i = 0; i < keys.length; i++) {
        for (var j = i + 1; j < keys.length; j++) {
          if (keys[i] == keys[j]) continue;
          batch.insert(
            _db.ignoredPairs,
            IgnoredPairsCompanion.insert(assetA: keys[i], assetB: keys[j]),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
    });
  }

  /// Deletes the group with [id] and its memberships.
  Future<void> deleteGroup(int id) =>
      (_db.delete(_db.duplicateGroups)..where((g) => g.id.equals(id))).go();

  /// Group id of every item in an exact or burst group, by item id.
  Future<Map<int, int>> certainGroups() async {
    final members = _db.duplicateMembers;
    final groups = _db.duplicateGroups;
    final query = _db.select(members).join([
      innerJoin(groups, groups.id.equalsExp(members.groupId)),
    ])..where(groups.kind.equalsValue(DuplicateKind.similar).not());
    return {
      for (final row in await query.get())
        row.readTable(members).assetId: row.readTable(members).groupId,
    };
  }

  /// Replaces the similar photo groups with [groups] (ids and confidence of
  /// each member, see `findSimilarGroups`), the item to keep marked
  /// ([pickBest]).
  Future<void> replaceSimilarGroups(
    List<SimilarGroup> groups, {
    DateTime? now,
  }) => _db.transaction(() async {
    final computedAt = now ?? DateTime.now();
    await (_db.delete(
      _db.duplicateGroups,
    )..where((g) => g.kind.equalsValue(DuplicateKind.similar))).go();
    for (final group in groups) {
      final rows = await (_db.select(
        _db.assets,
      )..where((t) => t.id.isIn(group.keys))).get();
      final items = [for (final row in rows) row.toMediaItem()];
      if (items.length < 2) continue;
      await _insertGroup(
        DuplicateKind.similar,
        items,
        computedAt,
        scores: group,
      );
    }
  });

  /// Replaces the exact duplicate and burst groups with the current ones,
  /// the item to keep marked ([pickBest]):
  ///
  /// - `exact`: items with the same content hash;
  /// - `burst`: items with the same burst id, unless they are all already
  ///   in one exact group.
  ///
  /// Trashed items stay in their groups; screens leave them out, so undoing
  /// a trash brings the group back.
  Future<void> rebuildGroups({DateTime? now}) => _db.transaction(() async {
    final computedAt = now ?? DateTime.now();
    await (_db.delete(_db.duplicateGroups)..where(
          (g) =>
              g.kind.equalsValue(DuplicateKind.exact) |
              g.kind.equalsValue(DuplicateKind.burst),
        ))
        .go();
    final exact = await _itemsSharing('content_hash', excluded: "''");
    for (final items in exact) {
      await _insertGroup(DuplicateKind.exact, items, computedAt);
    }
    final exactSets = {for (final items in exact) _key(items)};
    for (final items in await _itemsSharing('burst_id')) {
      // A burst saved twice is already an exact group.
      if (exactSets.contains(_key(items))) {
        continue;
      }
      await _insertGroup(DuplicateKind.burst, items, computedAt);
    }
  });

  /// The ids of [items], in order, as one string.
  static String _key(List<MediaItem> items) =>
      [for (final item in items) item.id].join(',');

  /// Items grouped by the value of [column], for every value held by two
  /// items or more; `NULL` and [excluded] (an SQL literal) are skipped.
  Future<List<List<MediaItem>>> _itemsSharing(
    String column, {
    String? excluded,
  }) async {
    final skip = excluded == null ? '' : 'AND $column != $excluded ';
    final rows = await _db
        .customSelect(
          'SELECT * FROM assets WHERE $column IN ( '
          'SELECT $column FROM assets '
          'WHERE $column IS NOT NULL $skip'
          'GROUP BY $column HAVING COUNT(*) > 1) '
          'ORDER BY $column, id',
          readsFrom: {_db.assets},
        )
        .get();
    final groups = <String, List<MediaItem>>{};
    for (final row in rows) {
      final key = row.read<String>(column);
      (groups[key] ??= []).add(_db.assets.map(row.data).toMediaItem());
    }
    return groups.values.toList();
  }

  Future<void> _insertGroup(
    DuplicateKind kind,
    List<MediaItem> items,
    DateTime computedAt, {
    Map<int, double> scores = const {},
  }) async {
    final groupId = await _db
        .into(_db.duplicateGroups)
        .insert(
          DuplicateGroupsCompanion.insert(kind: kind, computedAt: computedAt),
        );
    final best = pickBest(items);
    await _db.batch((batch) {
      batch.insertAll(_db.duplicateMembers, [
        for (final item in items)
          DuplicateMembersCompanion.insert(
            groupId: groupId,
            assetId: int.parse(item.id),
            isSuggestedKeep: Value(item.id == best.id),
            score: Value(scores[int.parse(item.id)] ?? 1),
          ),
      ]);
    });
  }
}
