import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:drift/drift.dart';

/// Slideshows saved by the user, in the `slideshows` and `slideshow_items`
/// tables.
///
/// A saved slideshow is its items in order and its options; nothing is
/// rendered or exported (ADR 0026). Items not in the media index, or in the
/// app trash, are skipped when it plays and are neither counted nor used as
/// its cover. See `docs/features/slideshow.md`.
final class SlideshowRepository {
  /// Creates the repository on [_db]; [correctedDates] as in
  /// [MediaIndexRepository], for the covers' dates.
  const SlideshowRepository(this._db, {this.correctedDates = true});

  final AppDatabase _db;

  /// Whether covers carry the resolved capture date.
  final bool correctedDates;

  /// Every saved slideshow with its count and cover, newest first, updated
  /// on every change of the slideshows, their items, the index or the
  /// trash.
  Stream<List<SavedSlideshow>> watchSaved() {
    // Items of slideshow `s` that are shown: indexed and not trashed.
    const shown =
        'FROM slideshow_items i JOIN assets a ON a.id = i.asset_id '
        'WHERE i.slideshow_id = s.id '
        'AND a.id NOT IN (SELECT asset_id FROM trash_entries)';
    final query = _db.customSelect(
      'SELECT s.id, s.title, s.options, s.created_at, '
      '(SELECT COUNT(*) $shown) AS n, '
      '(SELECT a.id $shown ORDER BY i.position LIMIT 1) AS cover '
      'FROM slideshows s '
      'ORDER BY s.created_at DESC, s.id DESC',
      readsFrom: {
        _db.slideshows,
        _db.slideshowItems,
        _db.assets,
        _db.trashEntries,
      },
    );
    return query.watch().asyncMap((rows) async {
      final covers = await _assets({
        for (final row in rows) ?row.read<int?>('cover'),
      });
      return [
        for (final row in rows)
          SavedSlideshow(
            id: row.read<int>('id'),
            title: row.read<String>('title'),
            options: SlideshowOptions.decode(row.read<String>('options')),
            count: row.read<int>('n'),
            createdAt: row.read<DateTime>('created_at'),
            cover: covers[row.read<int?>('cover')],
          ),
      ];
    });
  }

  /// Saves the items with [ids], in that order, with [options] under
  /// [title]; returns the new slideshow's id.
  Future<int> save(
    String title,
    SlideshowOptions options,
    List<String> ids, {
    DateTime? now,
  }) => _db.transaction(() async {
    final id = await _db
        .into(_db.slideshows)
        .insert(
          SlideshowsCompanion.insert(
            title: title.trim(),
            options: options.encode(),
            createdAt: now ?? DateTime.now(),
          ),
        );
    final keys = [for (final id in ids) ?int.tryParse(id)];
    await _db.batch((batch) {
      batch.insertAll(_db.slideshowItems, [
        for (final (position, key) in keys.indexed)
          SlideshowItemsCompanion.insert(
            slideshowId: id,
            position: position,
            assetId: key,
          ),
      ]);
    });
    return id;
  });

  /// The slideshow [id], or `null` when it does not exist (any more).
  Future<({String title, SlideshowOptions options})?> find(int id) async {
    final row = await (_db.select(
      _db.slideshows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return (title: row.title, options: SlideshowOptions.decode(row.options));
  }

  /// Ids of the items of slideshow [id] in playing order, including items
  /// that are no longer shown.
  Future<List<String>> itemIds(int id) async {
    final query = _db.select(_db.slideshowItems)
      ..where((t) => t.slideshowId.equals(id))
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    return [for (final row in await query.get()) '${row.assetId}'];
  }

  /// Renames slideshow [id].
  Future<void> rename(int id, String title) =>
      (_db.update(_db.slideshows)..where((t) => t.id.equals(id))).write(
        SlideshowsCompanion(title: Value(title.trim())),
      );

  /// Deletes slideshow [id] and its list of items; the files stay.
  /// Returns what [restore] needs to bring it back, or `null` when there
  /// was no such slideshow.
  Future<DeletedSlideshow?> delete(int id) => _db.transaction(() async {
    final row = await (_db.select(
      _db.slideshows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final items = await (_db.select(
      _db.slideshowItems,
    )..where((t) => t.slideshowId.equals(id))).get();
    // Its items go with it (cascade).
    await (_db.delete(_db.slideshows)..where((t) => t.id.equals(id))).go();
    return DeletedSlideshow(row, items);
  });

  /// Brings back a slideshow removed by [delete], with the same id.
  Future<void> restore(DeletedSlideshow deleted) => _db.transaction(() async {
    await _db.into(_db.slideshows).insert(deleted.slideshow);
    await _db.batch(
      (batch) => batch.insertAll(_db.slideshowItems, deleted.items),
    );
  });

  /// Music of every saved slideshow that plays a track from the phone, so
  /// the app keeps read access to those files only.
  Future<Set<String>> deviceMusicUris() async {
    final rows = await _db.select(_db.slideshows).get();
    return {
      for (final row in rows)
        if (SlideshowOptions.decode(row.options).music case DeviceMusic(
          :final uri,
        ))
          uri,
    };
  }

  /// Removes the items with [ids] from every slideshow, once they are
  /// deleted from the device for good. Positions keep their gaps; the
  /// order stays.
  Future<void> forget(Iterable<String> ids) {
    final keys = [for (final id in ids) ?int.tryParse(id)];
    return (_db.delete(
      _db.slideshowItems,
    )..where((t) => t.assetId.isIn(keys))).go();
  }

  Future<Map<int, MediaItem>> _assets(Set<int> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await (_db.select(
      _db.assets,
    )..where((t) => t.id.isIn(ids))).get();
    return {
      for (final row in rows)
        row.id: row.toMediaItem(correctedDates: correctedDates),
    };
  }
}

/// A slideshow removed by [SlideshowRepository.delete], kept so it can be
/// restored (Undo).
final class DeletedSlideshow {
  /// Wraps the slideshow's row and its items.
  const DeletedSlideshow(this.slideshow, this.items);

  /// The slideshow as it was.
  final SlideshowRow slideshow;

  /// Its items as they were.
  final List<SlideshowItemRow> items;
}
