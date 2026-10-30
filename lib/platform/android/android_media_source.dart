import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/geo.dart';
import 'package:clean_gallery/domain/gray_image.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/media_metadata.dart';
import 'package:clean_gallery/platform/android/android_platform_bridge.dart';
import 'package:clean_gallery/platform/android/media_image_providers.dart';
import 'package:clean_gallery/platform/media_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:photo_manager/photo_manager.dart';

/// [MediaSource] backed by Android's MediaStore.
///
/// The index queries ([snapshot], [describe]) and thumbnails go through the
/// app's own native channel; full images and video URIs through
/// `photo_manager`, whose permission check is turned off because
/// `PermissionService` requests permissions.
final class AndroidMediaSource implements MediaSource {
  /// Creates the source on [_bridge].
  AndroidMediaSource(this._bridge) {
    _ready = PhotoManager.setIgnorePermissionCheck(true);
  }

  final AndroidPlatformBridge _bridge;
  late final Future<void> _ready;

  @override
  Future<LibrarySnapshot> snapshot() async {
    final reply = await _bridge.mediaSnapshot();
    final ids = (reply['ids'] as List<Object?>?) ?? const [];
    final revisions = (reply['revisions'] as List<Object?>?) ?? const [];
    return LibrarySnapshot(
      version: '${reply['version'] ?? ''}',
      revisions: {
        for (var i = 0; i < ids.length; i++) '${ids[i]}': revisions[i]! as int,
      },
    );
  }

  @override
  Future<List<IndexedMedia>> describe(List<String> ids) async => [
    for (final row in await _bridge.mediaDetails(ids)) _toIndexed(row),
  ];

  @override
  Future<Map<String, String>> contentHashes(List<MediaItem> items) =>
      _bridge.contentHashes(items);

  @override
  Future<Map<String, GrayImage>> grayThumbnails(
    List<MediaItem> photos, {
    required int side,
  }) => _bridge.grayThumbnails([for (final p in photos) p.id], side: side);

  @override
  Future<Map<String, GeoPoint>> locations(List<MediaItem> items) =>
      _bridge.locations(items);

  @override
  Future<MediaMetadata> metadata(MediaItem item) async {
    final Map<String, Object?> row;
    try {
      row = await _bridge.mediaMetadata(item.id, video: item.isVideo);
    } on PlatformException {
      return MediaMetadata.empty;
    }
    double? number(String key) => (row[key] as num?)?.toDouble();
    return MediaMetadata(
      make: row['make'] as String?,
      model: row['model'] as String?,
      lens: row['lens'] as String?,
      iso: row['iso'] as int?,
      aperture: number('aperture'),
      exposure: number('exposure'),
      focalLength: number('focalLength'),
      focalLength35: number('focalLength35'),
      latitude: number('latitude'),
      longitude: number('longitude'),
    );
  }

  /// An item from one map of [AndroidPlatformBridge.mediaDetails].
  static IndexedMedia _toIndexed(Map<String, Object?> row) {
    final video = row['video']! as bool;
    final modified = DateTime.fromMillisecondsSinceEpoch(
      (row['modified']! as int) * 1000,
    );
    return IndexedMedia(
      item: MediaItem(
        id: row['id']! as String,
        kind: video ? MediaKind.video : MediaKind.photo,
        width: row['width']! as int,
        height: row['height']! as int,
        takenAt: DateTime.fromMillisecondsSinceEpoch(row['takenAt']! as int),
        modifiedAt: modified,
        duration: video
            ? Duration(milliseconds: row['duration']! as int)
            : Duration.zero,
        isFavorite: row['favorite']! as bool,
        sizeBytes: row['size']! as int,
        fileName: row['name'] as String?,
        relativePath: row['relativePath'] as String?,
        mimeType: row['mimeType'] as String?,
      ),
      albumId: row['bucketId'] as String?,
      albumName: row['bucketName']! as String,
      revision: row['revision']! as int,
      hasMetadataDate: hasMetadataDate(
        dateTaken: row['dateTaken']! as int,
        addedSeconds: row['added']! as int,
        modifiedSeconds: row['modified']! as int,
      ),
    );
  }

  /// Whether MediaStore's `DATE_TAKEN` ([dateTaken], milliseconds, 0 when
  /// unset) comes from the file's metadata.
  ///
  /// MediaStore fills it from EXIF or the video's creation time, but some
  /// devices copy the file date into it. A value within 2 seconds of the
  /// file's added or modified date is therefore not trusted, so the file
  /// name can be tried; for a camera photo saved right away both rules give
  /// the same date.
  static bool hasMetadataDate({
    required int dateTaken,
    required int addedSeconds,
    required int modifiedSeconds,
  }) {
    if (dateTaken <= 0) return false;
    bool near(int seconds) => (dateTaken - seconds * 1000).abs() < 2000;
    return !near(addedSeconds) && !near(modifiedSeconds);
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
    return _native(item, width, height, fromFile: true);
  }

  NativeThumbnailProvider _native(
    MediaItem item,
    int width,
    int height, {
    bool fromFile = false,
  }) => NativeThumbnailProvider(
    _bridge,
    id: item.id,
    isVideo: item.isVideo,
    modifiedSecond: item.modifiedAt.millisecondsSinceEpoch ~/ 1000,
    width: width,
    height: height,
    fromFile: fromFile,
  );

  @override
  ImageProvider fullImage(MediaItem item, {int maxDimension = 4096}) =>
      AssetFullImageProvider(_entity(item), maxDimension: maxDimension);

  @override
  Future<Uri?> videoUri(MediaItem item) async {
    await _ready;
    final url = await _entity(item).getMediaUrl();
    return url == null ? null : Uri.parse(url);
  }

  /// `photo_manager` entity for [item], built from its id.
  AssetEntity _entity(MediaItem item) => AssetEntity(
    id: item.id,
    typeInt: item.isVideo ? AssetType.video.index : AssetType.image.index,
    width: item.width,
    height: item.height,
    duration: item.duration.inSeconds,
    modifiedDateSecond: item.modifiedAt.millisecondsSinceEpoch ~/ 1000,
    title: item.fileName,
    relativePath: item.relativePath,
    mimeType: item.mimeType,
  );
}
