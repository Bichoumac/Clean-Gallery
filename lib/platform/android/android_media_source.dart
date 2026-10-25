import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
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
  /// Creates the source. Call nothing on `photo_manager` before this.
  AndroidMediaSource() {
    _ready = PhotoManager.setIgnorePermissionCheck(true);
  }

  late final Future<void> _ready;

  /// Assets loaded so far, by id.
  final _assets = <String, AssetEntity>{};

  /// Newest first, with file names (MediaStore `DISPLAY_NAME`).
  static final _defaultFilter = FilterOptionGroup(
    imageOption: const FilterOption(needTitle: true),
    videoOption: const FilterOption(needTitle: true),
    orders: const [OrderOption()],
  );

  /// Items with MediaStore `IS_FAVORITE = 1` (Android 11+), newest first.
  static final _favoritesFilter = CustomFilter.sql(
    where: '${CustomColumns.android.isFavorite} = 1',
    orderBy: [OrderByItem.desc(CustomColumns.android.createDate)],
  )..needTitle = true;

  @override
  Future<List<Album>> albums() async {
    await _ready;
    final paths = await PhotoManager.getAssetPathList(
      hasAll: false,
      filterOption: _defaultFilter,
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
    final entities = await path.getAssetListRange(start: start, end: end);
    return [
      for (final entity in entities)
        if (entity.type == AssetType.image || entity.type == AssetType.video)
          _toItem(entity),
    ];
  }

  @override
  ImageProvider thumbnail(MediaItem item, {required int size}) =>
      AssetThumbnailProvider(_entity(item), size: size);

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
    final albumId = selection.albumId;
    if (albumId != null) {
      final paths = await PhotoManager.getAssetPathList(
        hasAll: false,
        filterOption: _defaultFilter,
      );
      return paths.where((p) => p.id == albumId).firstOrNull;
    }
    final (type, filter) = switch (selection.filter) {
      MediaFilter.all => (RequestType.common, _defaultFilter),
      MediaFilter.photos => (RequestType.image, _defaultFilter),
      MediaFilter.videos => (RequestType.video, _defaultFilter),
      MediaFilter.favorites => (RequestType.common, _favoritesFilter),
    };
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

  MediaItem _toItem(AssetEntity entity) {
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
      fileName: entity.title,
      relativePath: entity.relativePath,
      mimeType: entity.mimeType,
    );
  }
}
