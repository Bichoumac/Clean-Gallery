import 'package:clean_gallery/analysis/best_picker.dart';
import 'package:clean_gallery/analysis/burst.dart';
import 'package:clean_gallery/analysis/capture_date.dart';
import 'package:clean_gallery/analysis/image_quality.dart';
import 'package:clean_gallery/analysis/screenshot.dart';
import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/duplicate_group.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/geo.dart';
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
  const MediaIndexRepository(
    this._db, {
    this.correctedDates = true,
    this.screen,
  });

  final AppDatabase _db;

  /// Whether reads use the resolved capture date.
  final bool correctedDates;

  /// Display size in physical pixels, to recognize screenshots by their
  /// size ([isScreenshot]); `null` when unknown.
  final ({int width, int height})? screen;

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
  /// Their capture date ([resolveCaptureDate]), burst id ([burstIdOf]) and
  /// whether they are screenshots ([isScreenshot]) are worked out on the
  /// way.
  ///
  /// When an item's file changed (modification date or size), its
  /// `analysis_version`, content hash, perceptual hashes and quality are
  /// reset so the engine analyses it again. With [resetAnalysis], every
  /// updated row is reset, e.g. after the platform rebuilt its database and
  /// ids may point to other files.
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
              burstId: excluded.burstId,
              isScreenshot: excluded.isScreenshot,
              isFavorite: excluded.isFavorite,
              mediaRevision: excluded.mediaRevision,
              analysisVersion: resetAnalysis
                  ? const Constant(0)
                  : _keptIfSameFile(old, excluded, old.analysisVersion, 0),
              contentHash: resetAnalysis
                  ? const Constant(null)
                  : _keptIfSameFile(old, excluded, old.contentHash, null),
              dHash: resetAnalysis
                  ? const Constant(null)
                  : _keptIfSameFile(old, excluded, old.dHash, null),
              pHash: resetAnalysis
                  ? const Constant(null)
                  : _keptIfSameFile(old, excluded, old.pHash, null),
              blurScore: resetAnalysis
                  ? const Constant(null)
                  : _keptIfSameFile(old, excluded, old.blurScore, null),
              brightness: resetAnalysis
                  ? const Constant(null)
                  : _keptIfSameFile(old, excluded, old.brightness, null),
              contrast: resetAnalysis
                  ? const Constant(null)
                  : _keptIfSameFile(old, excluded, old.contrast, null),
              latitude: resetAnalysis
                  ? const Constant(null)
                  : _keptIfSameFile(old, excluded, old.latitude, null),
              longitude: resetAnalysis
                  ? const Constant(null)
                  : _keptIfSameFile(old, excluded, old.longitude, null),
              locationRead: resetAnalysis
                  ? const Constant(false)
                  : _keptIfSameFile(old, excluded, old.locationRead, false),
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

  /// Forgets every analysis result, so the next sync and scan work out
  /// everything again: dates and burst ids (rows are described again),
  /// content and perceptual hashes, quality, locations and duplicate
  /// groups. Metadata,
  /// the trash, settings and the pairs marked "Not duplicates" are kept.
  Future<void> resetAnalysis() => _db.transaction(() async {
    await _db
        .update(_db.assets)
        .write(
          const AssetsCompanion(
            mediaRevision: Value(null),
            contentHash: Value(null),
            dHash: Value(null),
            pHash: Value(null),
            blurScore: Value(null),
            brightness: Value(null),
            contrast: Value(null),
            latitude: Value(null),
            longitude: Value(null),
            locationRead: Value(false),
            analysisVersion: Value(0),
          ),
        );
    await _db.delete(_db.duplicateGroups).go();
  });

  /// Up to [limit] items whose location is still to read, newest first, so
  /// recent places show first on the map. Trashed items are skipped.
  Future<List<MediaItem>> locationCandidates({required int limit}) async {
    final query = _db.select(_db.assets)
      ..where((t) => t.locationRead.equals(false) & _notTrashed(t))
      ..orderBy([
        (t) => OrderingTerm.desc(_date(t)),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(limit);
    return [for (final row in await query.get()) _toItem(row)];
  }

  /// Stores the locations of [items] found in [locations], by id; the
  /// others have none. All are marked read.
  Future<void> saveLocations(
    List<MediaItem> items,
    Map<String, GeoPoint> locations,
  ) => _db.batch((batch) {
    for (final item in items) {
      final position = locations[item.id];
      batch.update(
        _db.assets,
        AssetsCompanion(
          latitude: Value(position?.latitude),
          longitude: Value(position?.longitude),
          locationRead: const Value(true),
        ),
        where: (t) => t.id.equals(int.parse(item.id)),
      );
    }
  });

  /// Every item with a location, trashed ones left out, newest first.
  Future<List<LocatedItem>> located() async {
    final query = _db.select(_db.assets)
      ..where(
        (t) =>
            t.latitude.isNotNull() & t.longitude.isNotNull() & _notTrashed(t),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(_date(t)),
        (t) => OrderingTerm.desc(t.id),
      ]);
    return [
      for (final row in await query.get())
        LocatedItem(
          item: _toItem(row),
          position: (latitude: row.latitude!, longitude: row.longitude!),
        ),
    ];
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

  /// Where the date shown for item [id] comes from, or `null` when the
  /// item is not indexed. Without [correctedDates], or before the date is
  /// resolved, it is the platform's file date ([DateSource.file]).
  Future<DateSource?> dateSource(String id) async {
    final key = int.tryParse(id);
    if (key == null) return null;
    final row = await (_db.select(
      _db.assets,
    )..where((t) => t.id.equals(key))).getSingleOrNull();
    if (row == null) return null;
    final resolved = correctedDates && row.captureAt != null;
    return resolved ? row.captureSource ?? DateSource.file : DateSource.file;
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

  /// Months that have photos or videos, newest first, with their item
  /// count, trashed items left out. Each month is its first day, local
  /// time.
  Future<List<({DateTime month, int count})>> months() async {
    final date = correctedDates ? 'COALESCE(capture_at, taken_at)' : 'taken_at';
    final rows = await _db
        .customSelect(
          "SELECT strftime('%Y-%m', $date, 'unixepoch', 'localtime') AS month, "
          'COUNT(*) AS n '
          'FROM assets '
          'WHERE id NOT IN (SELECT asset_id FROM trash_entries) '
          'GROUP BY month '
          'ORDER BY month DESC',
          readsFrom: {_db.assets, _db.trashEntries},
        )
        .get();
    return [
      for (final row in rows)
        if (row.read<String?>('month') case final month?)
          (
            month: DateTime(
              int.parse(month.substring(0, 4)),
              int.parse(month.substring(5, 7)),
            ),
            count: row.read<int>('n'),
          ),
    ];
  }

  /// Number and total size of the photos and of the videos, trashed items
  /// left out: the space the library takes on the device.
  Future<MediaTotals> totals() async {
    final rows = await _db
        .customSelect(
          'SELECT kind, COUNT(*) AS n, COALESCE(SUM(size_bytes), 0) AS bytes '
          'FROM assets '
          'WHERE id NOT IN (SELECT asset_id FROM trash_entries) '
          'GROUP BY kind',
          readsFrom: {_db.assets, _db.trashEntries},
        )
        .get();
    var totals = (photos: 0, photoBytes: 0, videos: 0, videoBytes: 0);
    for (final row in rows) {
      final count = row.read<int>('n');
      final bytes = row.read<int>('bytes');
      totals = row.read<String>('kind') == MediaKind.video.name
          ? (
              photos: totals.photos,
              photoBytes: totals.photoBytes,
              videos: count,
              videoBytes: bytes,
            )
          : (
              photos: count,
              photoBytes: bytes,
              videos: totals.videos,
              videoBytes: totals.videoBytes,
            );
    }
    return totals;
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

  /// Condition selecting the rows of [selection] (filter, folder, dates,
  /// size).
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
        MediaFilter.screenshots =>
          t.kind.equalsValue(MediaKind.photo) & t.isScreenshot.equals(true),
        MediaFilter.largeVideos => t.kind.equalsValue(MediaKind.video),
        MediaFilter.poorQuality =>
          t.kind.equalsValue(MediaKind.photo) &
              t.isScreenshot.equals(false) &
              (_blurry(t) | t.brightness.isSmallerThanValue(darkBelow)),
      },
      if (selection.takenBefore case final before?)
        _date(t).isSmallerThanValue(before),
      if (selection.minSizeBytes case final bytes?)
        t.sizeBytes.isBiggerOrEqualValue(bytes),
      if (selection.albumId case final albumId?) t.bucketId.equals(albumId),
      if (selection.ids case final ids?)
        t.id.isIn([for (final id in ids) ?int.tryParse(id)]),
      if (selection.area case final area?) ...[
        t.latitude.isBiggerOrEqualValue(area.south),
        t.latitude.isSmallerThanValue(area.north),
        t.longitude.isBiggerOrEqualValue(area.west),
        t.longitude.isSmallerThanValue(area.east),
      ],
      if (dates?.start case final start?) _date(t).isBiggerOrEqualValue(start),
      if (dates?.end case final end?) _date(t).isSmallerThanValue(end),
    ]);
  }

  /// Condition on blurry photos, as [isBlurry]: below [blurryBelow], and
  /// below [hazyFrom] for their contrast when it is known.
  Expression<bool> _blurry($AssetsTable t) {
    final relativeSharpness = t.blurScore * const Constant<double>(1000);
    final hazyLimit = t.contrast * t.contrast * const Constant(hazyFrom);
    return t.blurScore.isSmallerThanValue(blurryBelow) &
        (t.contrast.isNull() |
            t.contrast.isSmallerOrEqualValue(0) |
            relativeSharpness.isSmallerThan(hazyLimit));
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
  AssetsCompanion _row(IndexedMedia entry) {
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
      burstId: Value(
        item.fileName == null
            ? null
            : burstIdOf(item.fileName!, folder: item.relativePath ?? ''),
      ),
      isScreenshot: Value(
        !item.isVideo &&
            isScreenshot(
              relativePath: item.relativePath ?? '',
              fileName: item.fileName ?? '',
              mimeType: item.mimeType ?? '',
              width: item.width,
              height: item.height,
              screen: screen,
            ),
      ),
      isFavorite: Value(item.isFavorite),
      mediaRevision: Value(entry.revision),
    );
  }
}

/// Number and total size in bytes of the photos and of the videos, see
/// [MediaIndexRepository.totals].
typedef MediaTotals = ({
  int photos,
  int photoBytes,
  int videos,
  int videoBytes,
});

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
    sharpness: blurScore,
    contrast: contrast,
  );
}
