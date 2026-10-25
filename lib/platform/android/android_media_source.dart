import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/platform/android/android_platform_bridge.dart';
import 'package:clean_gallery/platform/android/media_image_providers.dart';
import 'package:clean_gallery/platform/media_source.dart';
import 'package:flutter/widgets.dart';
import 'package:photo_manager/photo_manager.dart';

/// [MediaSource] backed by Android's MediaStore through `photo_manager`.
///
/// Permissions are requested by `PermissionService`, so `photo_manager`'s own
/// permission check is turned off. Loaded `AssetEntity`s are kept by id so
/// image providers can be built synchronously from a [MediaItem].
final class AndroidMediaSource implements MediaSource {
  /// Creates the source. [_bridge] provides what `photo_manager` lacks
  /// (file sizes).
  AndroidMediaSource(this._bridge) {
    _ready = PhotoManager.setIgnorePermissionCheck(true);
  }

  final AndroidPlatformBridge _bridge;
  late final Future<void> _ready;

  /// Assets loaded so far, by id.
  final _assets = <String, AssetEntity>{};

  /// Capture date in seconds, computed exactly like `photo_manager`'s
  /// `createDateTime`: `DATE_TAKEN` (milliseconds) when set, otherwise
  /// `DATE_ADDED`. Sorting and filtering on it keeps them consistent with
  /// the timeline headers.
  static const _captureDate =
      '(CASE WHEN datetaken > 0 THEN datetaken / 1000 ELSE date_added END)';

  /// MediaStore `MEDIA_TYPE` values.
  static const _imageType = 1;
  static const _videoType = 3;

  /// MediaStore query for [selection]: type, favorites and date conditions,
  /// and the sort order.
  ///
  /// `photo_manager` drops its own media-type condition as soon as a custom
  /// `where` is given, so the type condition is always written here.
  static CustomFilter _filterFor(MediaSelection selection) {
    final where = <String>[
      switch (selection.filter) {
        MediaFilter.photos => 'media_type = $_imageType',
        MediaFilter.videos => 'media_type = $_videoType',
        MediaFilter.all ||
        MediaFilter.favorites => 'media_type IN ($_imageType, $_videoType)',
      },
      if (selection.filter == MediaFilter.favorites)
        '${CustomColumns.android.isFavorite} = 1',
      if (selection.dates?.start case final start?)
        '$_captureDate >= ${start.millisecondsSinceEpoch ~/ 1000}',
      if (selection.dates?.end case final end?)
        '$_captureDate < ${end.millisecondsSinceEpoch ~/ 1000}',
    ];
    final sort = selection.sort;
    final asc = !sort.descending;
    final column = switch (sort.field) {
      MediaSortField.date => _captureDate,
      MediaSortField.name => 'LOWER(_display_name)',
      MediaSortField.size => '_size',
      MediaSortField.duration => 'duration',
    };
    return CustomFilter.sql(
      where: where.join(' AND '),
      orderBy: [
        OrderByItem(column, asc),
        // Stable order for equal values: newest first, then by id.
        if (sort.field != MediaSortField.date)
          const OrderByItem.desc(_captureDate),
        OrderByItem('_id', asc),
      ],
    )..needTitle = true;
  }

  @override
  Future<List<Album>> albums() async {
    await _ready;
    final paths = await PhotoManager.getAssetPathList(
      hasAll: false,
      filterOption: _filterFor(MediaSelection.all),
    );
    final albums = <Album>[];
    for (final path in paths) {
      final count = await path.assetCountAsync;
      if (count > 0) {
        albums.add(Album(id: path.id, name: path.name, count: count));
      }
    }
    albums.sort((a, b) => b.count.compareTo(a.count));
    return albums;
  }

  @override
  Future<int> count(MediaSelection selection) async {
    final path = await _path(selection);
    return path == null ? 0 : await path.assetCountAsync;
  }

  @override
  Future<List<MediaItem>> load(
    MediaSelection selection, {
    required int start,
    required int end,
  }) async {
    final path = await _path(selection);
    if (path == null || end <= start) return const [];
    final entities = [
      for (final entity in await path.getAssetListRange(start: start, end: end))
        if (entity.type == AssetType.image || entity.type == AssetType.video)
          entity,
    ];
    // One extra MediaStore query per chunk for the file sizes.
    final sizes = await _bridge.mediaSizes([for (final e in entities) e.id]);
    return [
      for (final entity in entities) _toItem(entity, sizes[entity.id] ?? 0),
    ];
  }

  @override
  ImageProvider thumbnail(MediaItem item, {required int size}) =>
      AssetThumbnailProvider(_entity(item), width: size, height: size);

  @override
  ImageProvider preview(MediaItem item, {required int longestSide}) {
    // Keep the proportions so Android neither crops nor pads the image.
    final ratio = item.aspectRatio;
    final (width, height) = ratio >= 1
        ? (longestSide, (longestSide / ratio).round())
        : ((longestSide * ratio).round(), longestSide);
    return AssetThumbnailProvider(
      _entity(item),
      width: width,
      height: height,
      quality: 90,
    );
  }

  @override
  ImageProvider fullImage(MediaItem item, {int maxDimension = 4096}) =>
      AssetFullImageProvider(_entity(item), maxDimension: maxDimension);

  @override
  Future<Uri?> videoUri(MediaItem item) async {
    final url = await _entity(item).getMediaUrl();
    return url == null ? null : Uri.parse(url);
  }

  /// The `photo_manager` path that lists [selection].
  Future<AssetPathEntity?> _path(MediaSelection selection) async {
    await _ready;
    final filter = _filterFor(selection);
    final type = switch (selection.filter) {
      MediaFilter.photos => RequestType.image,
      MediaFilter.videos => RequestType.video,
      MediaFilter.all || MediaFilter.favorites => RequestType.common,
    };
    final albumId = selection.albumId;
    if (albumId != null) {
      // A folder with no item matching the filter is not listed: count 0.
      final paths = await PhotoManager.getAssetPathList(
        hasAll: false,
        type: type,
        filterOption: filter,
      );
      return paths.where((p) => p.id == albumId).firstOrNull;
    }
    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: type,
      filterOption: filter,
    );
    return paths.firstOrNull;
  }

  /// Entity for [item], rebuilt from its id if it was never loaded here.
  AssetEntity _entity(MediaItem item) =>
      _assets[item.id] ??
      AssetEntity(
        id: item.id,
        typeInt: item.isVideo ? AssetType.video.index : AssetType.image.index,
        width: item.width,
        height: item.height,
        duration: item.duration.inSeconds,
        modifiedDateSecond: item.modifiedAt.millisecondsSinceEpoch ~/ 1000,
      );

  MediaItem _toItem(AssetEntity entity, int sizeBytes) {
    _assets[entity.id] = entity;
    return MediaItem(
      id: entity.id,
      kind: entity.type == AssetType.video ? MediaKind.video : MediaKind.photo,
      width: entity.orientatedWidth,
      height: entity.orientatedHeight,
      takenAt: entity.createDateTime,
      modifiedAt: entity.modifiedDateTime,
      duration: entity.videoDuration,
      isFavorite: entity.isFavorite,
      sizeBytes: sizeBytes,
      fileName: entity.title,
      relativePath: entity.relativePath,
      mimeType: entity.mimeType,
    );
  }
}
