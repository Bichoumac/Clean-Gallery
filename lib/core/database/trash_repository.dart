import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/trashed_item.dart';
import 'package:drift/drift.dart';

/// The app trash, stored in the `trash_entries` table.
///
/// Trashing never touches the file: it records the item so that every list
/// hides it. A minimal `assets` row is inserted with it, which satisfies the
/// foreign key and lets the trash screen show the item without asking
/// MediaStore. See `docs/features/trash.md`.
final class TrashRepository {
  /// Creates the repository on [_db].
  const TrashRepository(this._db);

  final AppDatabase _db;

  /// Ids of all trashed items, updated on every change.
  Stream<Set<String>> watchTrashedIds() {
    final query = _db.selectOnly(_db.trashEntries)
      ..addColumns([_db.trashEntries.assetId]);
    return query.watch().map(
      (rows) => {
        for (final row in rows) '${row.read(_db.trashEntries.assetId)}',
      },
    );
  }

  /// Trashed items, most recently trashed first, updated on every change.
  Stream<List<TrashedItem>> watchItems() => _itemsQuery().watch().map(
    (rows) => [for (final row in rows) _toTrashed(row)],
  );

  /// Items whose retention period is over at [now].
  Future<List<TrashedItem>> expired(DateTime now) async {
    final query = _itemsQuery()
      ..where(_db.trashEntries.expiresAt.isSmallerOrEqualValue(now));
    return [for (final row in await query.get()) _toTrashed(row)];
  }

  /// Moves [items] to the trash for [retentionDays] days from [now].
  Future<void> trash(
    List<MediaItem> items, {
    required int retentionDays,
    DateTime? now,
  }) async {
    final trashedAt = now ?? DateTime.now();
    final expiresAt = trashedAt.add(Duration(days: retentionDays));
    await _db.batch((batch) {
      batch
        ..insertAll(_db.assets, [
          for (final item in items) _assetRow(item),
        ], mode: InsertMode.insertOrIgnore)
        ..insertAll(_db.trashEntries, [
          for (final item in items)
            TrashEntriesCompanion.insert(
              assetId: Value(int.parse(item.id)),
              trashedAt: trashedAt,
              expiresAt: expiresAt,
              originalFolder: _folderOf(item),
            ),
        ], mode: InsertMode.insertOrReplace);
    });
  }

  /// Takes the items with [ids] out of the trash.
  Future<void> restore(Iterable<String> ids) {
    final keys = [for (final id in ids) int.parse(id)];
    return (_db.delete(
      _db.trashEntries,
    )..where((t) => t.assetId.isIn(keys))).go();
  }

  /// Forgets items deleted for good: their trash entries and asset rows.
  Future<void> forget(Iterable<String> ids) {
    final keys = [for (final id in ids) int.parse(id)];
    // Deleting the asset rows cascades to their trash entries.
    return (_db.delete(_db.assets)..where((t) => t.id.isIn(keys))).go();
  }

  JoinedSelectStatement<HasResultSet, dynamic> _itemsQuery() =>
      _db.select(_db.trashEntries).join([
        innerJoin(
          _db.assets,
          _db.assets.id.equalsExp(_db.trashEntries.assetId),
        ),
      ])..orderBy([OrderingTerm.desc(_db.trashEntries.trashedAt)]);

  TrashedItem _toTrashed(TypedResult row) {
    final entry = row.readTable(_db.trashEntries);
    final asset = row.readTable(_db.assets);
    return TrashedItem(
      item: MediaItem(
        id: '${asset.id}',
        kind: asset.kind,
        width: asset.width,
        height: asset.height,
        takenAt: asset.captureAt ?? asset.modifiedAt,
        modifiedAt: asset.modifiedAt,
        duration: Duration(milliseconds: asset.durationMs ?? 0),
        isFavorite: asset.isFavorite,
        sizeBytes: asset.sizeBytes,
        fileName: asset.fileName.isEmpty ? null : asset.fileName,
        relativePath: asset.relativePath.isEmpty ? null : asset.relativePath,
        mimeType: asset.mimeType.isEmpty ? null : asset.mimeType,
      ),
      trashedAt: entry.trashedAt,
      expiresAt: entry.expiresAt,
      originalFolder: entry.originalFolder,
    );
  }

  AssetsCompanion _assetRow(MediaItem item) => AssetsCompanion.insert(
    id: Value(int.parse(item.id)),
    folder: _folderOf(item),
    relativePath: item.relativePath ?? '',
    fileName: item.fileName ?? '',
    mimeType: item.mimeType ?? '',
    kind: item.kind,
    sizeBytes: item.sizeBytes,
    width: item.width,
    height: item.height,
    durationMs: Value(item.isVideo ? item.duration.inMilliseconds : null),
    modifiedAt: item.modifiedAt,
    captureAt: Value(item.takenAt),
    isFavorite: Value(item.isFavorite),
  );

  /// Last folder of the item's path: `DCIM/Camera/` → `Camera`.
  String _folderOf(MediaItem item) {
    final parts = (item.relativePath ?? '').split('/')
      ..removeWhere((p) => p.isEmpty);
    return parts.isEmpty ? '' : parts.last;
  }
}
