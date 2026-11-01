import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:drift/drift.dart';

/// The albums created by the user, in the `user_albums` and
/// `user_album_items` tables.
///
/// Only rows change here: no file is ever moved, copied or deleted for an
/// album (ADR 0025).
/// Items not in the media index, or in the app trash, are neither shown nor
/// counted. See `docs/features/user-albums.md`.
final class UserAlbumRepository {
  /// Creates the repository on [_db]; [correctedDates] as in
  /// [MediaIndexRepository], for the newest item used as cover.
  const UserAlbumRepository(this._db, {this.correctedDates = true});

  final AppDatabase _db;

  /// Whether covers are the newest item by resolved capture date.
  final bool correctedDates;

  /// Every album with its count and cover, newest album first, updated on
  /// every change of the albums, their items, the index or the trash.
  Stream<List<UserAlbum>> watchAlbums() {
    final date = correctedDates
        ? 'COALESCE(a.capture_at, a.taken_at)'
        : 'a.taken_at';
    // Items of album `u` that are shown: indexed and not trashed.
    const shown =
        'FROM user_album_items i JOIN assets a ON a.id = i.asset_id '
        'WHERE i.album_id = u.id '
        'AND a.id NOT IN (SELECT asset_id FROM trash_entries)';
    final query = _db.customSelect(
      'SELECT u.id, u.name, '
      '(SELECT COUNT(*) $shown) AS n, '
      'COALESCE((SELECT a.id $shown AND a.id = u.cover_asset_id), '
      '(SELECT a.id $shown ORDER BY $date DESC, a.id DESC LIMIT 1)) AS cover '
      'FROM user_albums u '
      'ORDER BY u.created_at DESC, u.id DESC',
      readsFrom: {
        _db.userAlbums,
        _db.userAlbumItems,
        _db.assets,
        _db.trashEntries,
      },
    );
    return query.watch().asyncMap((rows) async {
      final coverIds = {for (final row in rows) ?row.read<int?>('cover')};
      final covers = coverIds.isEmpty
          ? const <int, AssetRow>{}
          : {
              for (final asset in await (_db.select(
                _db.assets,
              )..where((t) => t.id.isIn(coverIds))).get())
                asset.id: asset,
            };
      return [
        for (final row in rows)
          UserAlbum(
            id: row.read<int>('id'),
            name: row.read<String>('name'),
            count: row.read<int>('n'),
            cover: covers[row.read<int?>('cover')]?.toMediaItem(
              correctedDates: correctedDates,
            ),
          ),
      ];
    });
  }

  /// A number increased on every write to `user_album_items`, so album
  /// pages reload.
  Stream<int> watchItemChanges() {
    var changes = 0;
    return _db
        .tableUpdates(TableUpdateQuery.onTable(_db.userAlbumItems))
        .map((_) => ++changes);
  }

  /// Creates an empty album named [name]; returns its id.
  Future<int> create(String name, {DateTime? now}) => _db
      .into(_db.userAlbums)
      .insert(
        UserAlbumsCompanion.insert(
          name: name.trim(),
          createdAt: now ?? DateTime.now(),
        ),
      );

  /// Renames album [id].
  Future<void> rename(int id, String name) =>
      (_db.update(_db.userAlbums)..where((t) => t.id.equals(id))).write(
        UserAlbumsCompanion(name: Value(name.trim())),
      );

  /// Adds the items with [ids] to album [albumId]; returns how many were
  /// not in it yet.
  Future<int> add(int albumId, Iterable<String> ids, {DateTime? now}) =>
      _db.transaction(() async {
        final keys = {for (final id in ids) ?int.tryParse(id)};
        final present = await _members(albumId, keys);
        final added = keys.difference(present);
        final at = now ?? DateTime.now();
        await _db.batch((batch) {
          batch.insertAll(_db.userAlbumItems, [
            for (final key in added)
              UserAlbumItemsCompanion.insert(
                albumId: albumId,
                assetId: key,
                addedAt: at,
              ),
          ]);
        });
        return added.length;
      });

  /// Removes the items with [ids] from album [albumId]; the files stay.
  Future<void> remove(int albumId, Iterable<String> ids) {
    final keys = [for (final id in ids) ?int.tryParse(id)];
    return (_db.delete(
      _db.userAlbumItems,
    )..where((t) => t.albumId.equals(albumId) & t.assetId.isIn(keys))).go();
  }

  /// Uses item [id] as the cover of album [albumId], or the newest item
  /// when `null`.
  Future<void> setCover(int albumId, String? id) =>
      (_db.update(_db.userAlbums)..where((t) => t.id.equals(albumId))).write(
        UserAlbumsCompanion(
          coverAssetId: Value(id == null ? null : int.tryParse(id)),
        ),
      );

  /// Deletes album [id] and its list of items; the files stay. Returns what
  /// [restore] needs to bring it back, or `null` when there was no such
  /// album.
  Future<DeletedUserAlbum?> delete(int id) => _db.transaction(() async {
    final album = await (_db.select(
      _db.userAlbums,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (album == null) return null;
    final items = await (_db.select(
      _db.userAlbumItems,
    )..where((t) => t.albumId.equals(id))).get();
    // Its items go with it (cascade).
    await (_db.delete(_db.userAlbums)..where((t) => t.id.equals(id))).go();
    return DeletedUserAlbum(album, items);
  });

  /// Brings back an album removed by [delete], with the same id and items.
  Future<void> restore(DeletedUserAlbum deleted) => _db.transaction(() async {
    await _db.into(_db.userAlbums).insert(deleted.album);
    await _db.batch(
      (batch) => batch.insertAll(_db.userAlbumItems, deleted.items),
    );
  });

  /// Number of the items with [ids] already in each album, by album id;
  /// albums holding none are left out.
  Future<Map<int, int>> containing(Iterable<String> ids) async {
    final keys = [for (final id in ids) ?int.tryParse(id)];
    final items = _db.userAlbumItems;
    final n = items.assetId.count();
    final query = _db.selectOnly(items)
      ..addColumns([items.albumId, n])
      ..where(items.assetId.isIn(keys))
      ..groupBy([items.albumId]);
    return {
      for (final row in await query.get())
        row.read(items.albumId)!: row.read(n)!,
    };
  }

  /// Removes the items with [ids] from every album, once they are deleted
  /// from the device for good.
  Future<void> forget(Iterable<String> ids) {
    final keys = [for (final id in ids) ?int.tryParse(id)];
    return (_db.delete(
      _db.userAlbumItems,
    )..where((t) => t.assetId.isIn(keys))).go();
  }

  /// Which of [keys] are in album [albumId].
  Future<Set<int>> _members(int albumId, Set<int> keys) async {
    final items = _db.userAlbumItems;
    final query = _db.selectOnly(items)
      ..addColumns([items.assetId])
      ..where(items.albumId.equals(albumId) & items.assetId.isIn(keys));
    return {for (final row in await query.get()) row.read(items.assetId)!};
  }
}

/// An album removed by [UserAlbumRepository.delete], kept so it can be
/// restored (Undo).
final class DeletedUserAlbum {
  /// Wraps the album's row and its items.
  const DeletedUserAlbum(this.album, this.items);

  /// The album as it was.
  final UserAlbumRow album;

  /// Its items as they were.
  final List<UserAlbumItemRow> items;
}
