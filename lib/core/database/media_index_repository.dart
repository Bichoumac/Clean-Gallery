import 'package:clean_gallery/analysis/best_picker.dart';
import 'package:clean_gallery/analysis/capture_date.dart';
import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/duplicate_group.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/platform/media_source.dart';
import 'package:drift/drift.dart';

/// The media index: a copy of the library's metadata in the `assets` table,
/// read by every list of the app.
///
/// `MediaIndex` keeps it in sync with the device; this class only reads and
/// writes rows. Queries mirror what MediaStore used to answer, so sorting
/// and filtering behave the same. See `docs/database.md`.
///
/// With [correctedDates], items are sorted, filtered and dated by their
/// resolved capture date (`capture_at`, see `resolveCaptureDate`);
/// otherwise by the platform's date (`taken_at`).
final class MediaIndexRepository {
  /// Creates the repository on [_db].
  const MediaIndexRepository(this._db, {this.correctedDates = true});

  final AppDatabase _db;

  /// Whether reads use the resolved capture date.
  final bool correctedDates;

  /// Revision of every indexed item, by id; `null` for rows that were never
  /// indexed (inserted by the trash).
  Future<Map<int, int?>> revisions() async {
    final query = _db.selectOnly(_db.assets)
      ..addColumns([_db.assets.id, _db.assets.mediaRevision]);
    return {
      for (final row in await query.get())
        row.read(_db.assets.id)!: row.read(_db.assets.mediaRevision),
    };
  }

  /// Inserts [entries] or updates their metadata, keeping analysis results.
  /// Their capture date is resolved on the way ([resolveCaptureDate]).
  ///
  /// When an item's file changed (modification date or size), its
  /// `analysis_version` and content hash are reset so the engine analyses
  /// it again. With
  /// [resetAnalysis], every updated row is reset, e.g. after the platform
  /// rebuilt its database and ids may point to other files.
  Future<void> upsert(
    List<IndexedMedia> entries, {
    bool resetAnalysis = false,
  }) async {
    if (entries.isEmpty) return;
    final assets = _db.assets;
    await _db.batch((batch) {
      for (final entry in entries) {
        batch.insert(
          assets,
          _row(entry),
          onConflict: DoUpdate<$AssetsTable, AssetRow>.withExcluded(
            (old, excluded) => AssetsCompanion.custom(
              folder: excluded.folder,
              bucketId: excluded.bucketId,
              relativePath: excluded.relativePath,
              fileName: excluded.fileName,
              mimeType: excluded.mimeType,
              kind: excluded.kind,
              sizeBytes: excluded.sizeBytes,
              width: excluded.width,
              height: excluded.height,
              durationMs: excluded.durationMs,
              modifiedAt: excluded.modifiedAt,
              takenAt: excluded.takenAt,
              captureAt: excluded.captureAt,
              captureSource: excluded.captureSource,
              isFavorite: excluded.isFavorite,
              mediaRevision: excluded.mediaRevision,
              analysisVersion: resetAnalysis
                  ? const Constant(0)
                  : _keptIfSameFile(old, excluded, old.analysisVersion, 0),
              contentHash: resetAnalysis
                  ? const Constant(null)
                  : _keptIfSameFile(old, excluded, old.contentHash, null),
            ),
          ),
        );
      }
    });
  }

  /// [kept] when the file of [old] did not change (same modification date
  /// and size as [excluded]), [otherwise] when it did.
  static Expression<T> _keptIfSameFile<T extends Object>(
    $AssetsTable old,
    $AssetsTable excluded,
    Expression<T> kept,
    T? otherwise,
  ) => CaseWhenExpression(
    cases: [
      CaseWhen(
        old.modifiedAt.equalsExp(excluded.modifiedAt) &
            old.sizeBytes.equalsExp(excluded.sizeBytes),
        then: kept,
      ),
    ],
    orElse: Variable<T>(otherwise),
  );

  /// Removes the items with [ids], which no longer exist on the device.
  ///
  /// Their trash entries and analysis results go with them (cascade). With
  /// [keepTrashed], trashed items are kept: with limited access, the
  /// platform hides items the user did not pick, which may still exist.
  Future<void> remove(Iterable<int> ids, {bool keepTrashed = false}) async {
    final keys = ids.toList();
    if (keys.isEmpty) return;
    final query = _db.delete(_db.assets)
      ..where(
        (t) => keepTrashed ? t.id.isIn(keys) & _notTrashed(t) : t.id.isIn(keys),
      );
    await query.go();
  }

  /// Records the favorite state of the items with [ids], after the system
  /// applied it.
  Future<void> setFavorite(Iterable<String> ids, {required bool favorite}) {
    final keys = [for (final id in ids) int.parse(id)];
    return (_db.update(_db.assets)..where((t) => t.id.isIn(keys))).write(
      AssetsCompanion(isFavorite: Value(favorite)),
    );
  }

  /// Items `[offset, offset + limit)` of [selection] in its sort order, or
  /// every item from [offset] when [limit] is `null`. Trashed items are
  /// included; screens hide them in memory.
  Future<List<MediaItem>> load(
    MediaSelection selection, {
    int offset = 0,
    int? limit,
  }) async {
    final query = _db.select(_db.assets)
      ..where((t) => _matches(t, selection))
      ..orderBy(_order(selection.sort));
    if (limit != null) {
      query.limit(limit, offset: offset);
    } else if (offset > 0) {
      // SQLite needs a LIMIT before an OFFSET; -1 means no limit.
      query.limit(-1, offset: offset);
    }
    return [for (final row in await query.get()) _toItem(row)];
  }

  /// Number of items in [selection], leaving out trashed items.
  Future<int> count(MediaSelection selection) async {
    final assets = _db.assets;
    final total = assets.id.count();
    final query = _db.selectOnly(assets)
      ..addColumns([total])
      ..where(_matches(assets, selection) & _notTrashed(assets));
    final row = await query.getSingle();
    return row.read<int>(total)!;
  }

  /// Newest item of [selection], leaving out trashed items: album covers.
  Future<MediaItem?> newest(MediaSelection selection) async {
    final query = _db.select(_db.assets)
      ..where((t) => _matches(t, selection) & _notTrashed(t))
      ..orderBy(_order(MediaSort.newest))
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _toItem(row);
  }

  /// Device folders with their item count and newest item, largest first,
  /// leaving out trashed items.
  Future<List<Album>> albums() async {
    // SQLite returns the other columns of the row holding the MAX(), so
    // each folder comes with its newest item in one pass.
    final date = correctedDates ? 'COALESCE(capture_at, taken_at)' : 'taken_at';
    final rows = await _db
        .customSelect(
          'SELECT *, COUNT(*) AS item_count, MAX($date) '
          'FROM assets '
          'WHERE bucket_id IS NOT NULL '
          'AND id NOT IN (SELECT asset_id FROM trash_entries) '
          'GROUP BY bucket_id '
          'ORDER BY item_count DESC, folder',
          readsFrom: {_db.assets, _db.trashEntries},
        )
        .get();
    return [for (final row in rows) _album(row)];
  }

  /// Duplicate groups among the items of [selection], trashed items left
  /// out, newest first. Groups are stored for the whole library; here each
  /// keeps only its members in [selection] and is dropped below two. The
  /// item to keep is picked again among the remaining members.
  Future<List<DuplicateGroup>> duplicateGroups(MediaSelection selection) async {
    final assets = _db.assets;
    final members = _db.duplicateMembers;
    final groups = _db.duplicateGroups;
    final query = _db.select(assets).join([
      innerJoin(members, members.assetId.equalsExp(assets.id)),
      innerJoin(groups, groups.id.equalsExp(members.groupId)),
    ])..where(_matches(assets, selection) & _notTrashed(assets));
    final kinds = <int, DuplicateKind>{};
    final items = <int, List<MediaItem>>{};
    for (final row in await query.get()) {
      final group = row.readTable(groups);
      kinds[group.id] = group.kind;
      (items[group.id] ??= []).add(_toItem(row.readTable(assets)));
    }
    return [
      for (final MapEntry(key: id, value: members) in items.entries)
        if (members.length > 1)
          DuplicateGroup(id: id, kind: kinds[id]!, items: bestFirst(members)),
    ]..sort((a, b) => b.best.takenAt.compareTo(a.best.takenAt));
  }

  Album _album(QueryRow row) {
    final cover = _db.assets.map(row.data);
    return Album(
      id: cover.bucketId!,
      name: cover.folder,
      count: row.read<int>('item_count'),
      cover: _toItem(cover),
    );
  }

  /// Condition selecting the rows of [selection] (filter, folder, dates).
  Expression<bool> _matches($AssetsTable t, MediaSelection selection) {
    final dates = selection.dates;
    return Expression.and([
      switch (selection.filter) {
        MediaFilter.all => const Constant(true),
        MediaFilter.photos => t.kind.equalsValue(MediaKind.photo),
        MediaFilter.camera =>
          t.kind.equalsValue(MediaKind.photo) &
              t.relativePath.like('$cameraFolder%'),
        MediaFilter.videos => t.kind.equalsValue(MediaKind.video),
        MediaFilter.favorites => t.isFavorite.equals(true),
      },
      if (selection.albumId case final albumId?) t.bucketId.equals(albumId),
      if (selection.ids case final ids?)
        t.id.isIn([for (final id in ids) ?int.tryParse(id)]),
      if (dates?.start case final start?) _date(t).isBiggerOrEqualValue(start),
      if (dates?.end case final end?) _date(t).isSmallerThanValue(end),
    ]);
  }

  /// Condition leaving out items in the app trash.
  Expression<bool> _notTrashed($AssetsTable t) {
    final trash = _db.trashEntries;
    return t.id.isNotInQuery(
      _db.selectOnly(trash)..addColumns([trash.assetId]),
    );
  }

  /// Order of [sort]; equal values are ordered newest first, then by id.
  List<OrderClauseGenerator<$AssetsTable>> _order(MediaSort sort) {
    final mode = sort.descending ? OrderingMode.desc : OrderingMode.asc;
    return [
      (t) => OrderingTerm(
        expression: switch (sort.field) {
          MediaSortField.date => _date(t),
          MediaSortField.name => t.fileName.lower(),
          MediaSortField.size => t.sizeBytes,
          MediaSortField.duration => coalesce([
            t.durationMs,
            const Constant(0),
          ]),
        },
        mode: mode,
      ),
      if (sort.field != MediaSortField.date) (t) => OrderingTerm.desc(_date(t)),
      (t) => OrderingTerm(expression: t.id, mode: mode),
    ];
  }

  /// Date items are sorted, filtered and dated by.
  Expression<DateTime> _date($AssetsTable t) =>
      correctedDates ? coalesce([t.captureAt, t.takenAt]) : t.takenAt;

  MediaItem _toItem(AssetRow row) =>
      row.toMediaItem(correctedDates: correctedDates);

  /// Row inserted for [entry]; analysis columns keep their defaults.
  static AssetsCompanion _row(IndexedMedia entry) {
    final item = entry.item;
    final capture = resolveCaptureDate(
      platformDate: item.takenAt,
      fromMetadata: entry.hasMetadataDate,
      fileName: item.fileName,
    );
    return AssetsCompanion.insert(
      id: Value(int.parse(item.id)),
      folder: entry.albumName,
      bucketId: Value(entry.albumId),
      relativePath: item.relativePath ?? '',
      fileName: item.fileName ?? '',
      mimeType: item.mimeType ?? '',
      kind: item.kind,
      sizeBytes: item.sizeBytes,
      width: item.width,
      height: item.height,
      durationMs: Value(item.isVideo ? item.duration.inMilliseconds : null),
      modifiedAt: item.modifiedAt,
      takenAt: item.takenAt,
      captureAt: Value(capture.date),
      captureSource: Value(capture.source),
      isFavorite: Value(item.isFavorite),
      mediaRevision: Value(entry.revision),
    );
  }
}

/// Folder the device camera saves to, as a `relative_path` prefix. The same
/// on Samsung and Pixel phones.
const cameraFolder = 'DCIM/Camera/';

/// Conversion of an index row to the domain item shown by screens.
extension AssetRowToMediaItem on AssetRow {
  /// This row as a [MediaItem]; empty texts become `null`. Its date is the
  /// resolved capture date with [correctedDates] (when known), the
  /// platform's otherwise.
  MediaItem toMediaItem({bool correctedDates = true}) => MediaItem(
    id: '$id',
    kind: kind,
    width: width,
    height: height,
    takenAt: correctedDates ? captureAt ?? takenAt : takenAt,
    modifiedAt: modifiedAt,
    duration: Duration(milliseconds: durationMs ?? 0),
    isFavorite: isFavorite,
    sizeBytes: sizeBytes,
    fileName: fileName.isEmpty ? null : fileName,
    relativePath: relativePath.isEmpty ? null : relativePath,
    mimeType: mimeType.isEmpty ? null : mimeType,
  );
}
