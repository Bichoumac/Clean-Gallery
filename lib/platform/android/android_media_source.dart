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
    // One native pass gives every folder's count and cover. Folder paths
    // are listed again on the next album page, so drop the cached ones.
    _folderPaths.clear();
    final summaries = await _bridge.albumSummaries();
    return [
      for (final summary in summaries)
        Album(
          id: summary['id']! as String,
          name: summary['name']! as String,
          count: summary['count']! as int,
          cover: _coverItem(summary),
        ),
    ];
  }

  /// Cover of a folder from its native summary. Only what a thumbnail needs
  /// is known: id, kind, size and modification time.
  MediaItem _coverItem(Map<String, Object?> summary) {
    final modified = DateTime.fromMillisecondsSinceEpoch(
      (summary['coverModified']! as int) * 1000,
    );
    return MediaItem(
      id: summary['coverId']! as String,
      kind: summary['coverIsVideo']! as bool
          ? MediaKind.video
          : MediaKind.photo,
      width: summary['coverWidth']! as int,
      height: summary['coverHeight']! as int,
      takenAt: modified,
      modifiedAt: modified,
    );
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
  ImageProvider thumbnail(MediaItem item, {required int size}) {
    // Grid cells crop to a square: make the short side [size] so the
    // cropped image is never upscaled.
    final ratio = item.aspectRatio;
    final (width, height) = ratio >= 1
        ? ((size * ratio).round(), size)
        : (size, (size / ratio).round());
    return _native(item, width, height);
  }

  @override
  ImageProvider preview(MediaItem item, {required int longestSide}) {
    // Keep the proportions so the whole image fits the requested size.
    final ratio = item.aspectRatio;
    final (width, height) = ratio >= 1
        ? (longestSide, (longestSide / ratio).round())
        : ((longestSide * ratio).round(), longestSide);
    return _native(item, width, height);
  }

  NativeThumbnailProvider _native(MediaItem item, int width, int height) =>
      NativeThumbnailProvider(
        _bridge,
        id: item.id,
        isVideo: item.isVideo,
        modifiedSecond: item.modifiedAt.millisecondsSinceEpoch ~/ 1000,
        width: width,
        height: height,
      );

  @override
  ImageProvider fullImage(MediaItem item, {int maxDimension = 4096}) =>
      AssetFullImageProvider(_entity(item), maxDimension: maxDimension);

  @override
  Future<Uri?> videoUri(MediaItem item) async {
    final url = await _entity(item).getMediaUrl();
    return url == null ? null : Uri.parse(url);
  }

  /// Folder paths by id, per selection without folder (same filter, sort
  /// and dates). Listing every folder is a full MediaStore query, so it is
  /// done once per filter instead of once per chunk or per album page.
  final _folderPaths = <MediaSelection, Map<String, AssetPathEntity>>{};

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
      final key = selection.copyWith(albumId: null);
      final folders = _folderPaths[key] ??= {
        for (final path in await PhotoManager.getAssetPathList(
          hasAll: false,
          type: type,
          filterOption: filter,
        ))
          path.id: path,
      };
      // A folder with no item matching the filter is not listed: count 0.
      return folders[albumId];
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
