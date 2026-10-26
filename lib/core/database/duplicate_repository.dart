import 'package:clean_gallery/analysis/best_picker.dart';
import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:drift/drift.dart';

/// Content hash stored for an item that could not be read, so it is not
/// tried again until its file changes. Never grouped.
const unreadableHash = '';

/// Writes of the duplicate detection: content hashes in `assets` and the
/// groups in `duplicate_groups` and `duplicate_members`.
///
/// Reads for screens are in `MediaIndexRepository.duplicateGroups`. See
/// `docs/analysis-engine.md#exact-duplicates`.
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

  /// Replaces the exact duplicate groups with the current ones: items with
  /// the same content hash, the item to keep marked ([pickBest]).
  ///
  /// Trashed items stay in their groups; screens leave them out, so undoing
  /// a trash brings the group back.
  Future<void> rebuildExactGroups({DateTime? now}) => _db.transaction(() async {
    final computedAt = now ?? DateTime.now();
    await (_db.delete(
      _db.duplicateGroups,
    )..where((g) => g.kind.equalsValue(DuplicateKind.exact))).go();

    final rows = await _db
        .customSelect(
          'SELECT * FROM assets WHERE content_hash IN ( '
          'SELECT content_hash FROM assets '
          "WHERE content_hash IS NOT NULL AND content_hash != '' "
          'GROUP BY content_hash HAVING COUNT(*) > 1) '
          'ORDER BY content_hash, id',
          readsFrom: {_db.assets},
        )
        .get();
    final byHash = <String, List<MediaItem>>{};
    for (final row in rows) {
      final asset = _db.assets.map(row.data);
      (byHash[asset.contentHash!] ??= []).add(asset.toMediaItem());
    }

    for (final items in byHash.values) {
      final groupId = await _db
          .into(_db.duplicateGroups)
          .insert(
            DuplicateGroupsCompanion.insert(
              kind: DuplicateKind.exact,
              computedAt: computedAt,
            ),
          );
      final best = pickBest(items);
      await _db.batch((batch) {
        batch.insertAll(_db.duplicateMembers, [
          for (final item in items)
            DuplicateMembersCompanion.insert(
              groupId: groupId,
              assetId: int.parse(item.id),
              isSuggestedKeep: Value(item.id == best.id),
            ),
        ]);
      });
    }
  });
}
