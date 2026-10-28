import 'package:clean_gallery/domain/geo.dart';
import 'package:clean_gallery/domain/gray_image.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/platform/platform_bridge.dart';
import 'package:flutter/services.dart';

/// Android implementation of [PlatformBridge] over the `clean_gallery/platform`
/// MethodChannel, handled by `MainActivity.kt`.
///
/// Method contract is documented in `docs/platform-android.md`.
final class AndroidPlatformBridge implements PlatformBridge {
  /// Creates the bridge. [channel] can be replaced in tests.
  AndroidPlatformBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'clean_gallery/platform';

  final MethodChannel _channel;

  @override
  Future<bool> isMediaManagementGranted() async {
    final granted = await _channel.invokeMethod<bool>(
      'isMediaManagementGranted',
    );
    return granted ?? false;
  }

  @override
  Future<void> openMediaManagementSettings() {
    return _channel.invokeMethod<void>('openMediaManagementSettings');
  }

  /// MediaStore version and, newest first, the id and revision
  /// (`GENERATION_MODIFIED`) of every photo and video.
  ///
  /// Android-only helper used by `AndroidMediaSource.snapshot`. The map has
  /// `version` (a string) and `ids` and `revisions`, two lists of the same
  /// length.
  Future<Map<String, Object?>> mediaSnapshot() async {
    final reply = await _channel.invokeMapMethod<String, Object?>(
      'mediaSnapshot',
    );
    return reply ?? const {};
  }

  /// Full metadata of the MediaStore items with the given [ids], one map
  /// per item; items that no longer exist are left out.
  ///
  /// Android-only helper used by `AndroidMediaSource.describe`. Keys are
  /// listed in `docs/platform-android.md`.
  Future<List<Map<String, Object?>>> mediaDetails(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final list = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'mediaDetails',
      {'ids': ids},
    );
    return [
      for (final entry in list ?? const <Map<Object?, Object?>>[])
        entry.cast<String, Object?>(),
    ];
  }

  /// Camera and location metadata of the MediaStore item [id], as a map
  /// whose keys are listed in `docs/platform-android.md`; missing values
  /// are left out.
  ///
  /// Android-only helper used by `AndroidMediaSource.metadata`.
  Future<Map<String, Object?>> mediaMetadata(
    String id, {
    required bool video,
  }) async {
    final reply = await _channel.invokeMapMethod<String, Object?>(
      'mediaMetadata',
      {'id': id, 'video': video},
    );
    return reply ?? const {};
  }

  /// SHA-256 of the content of [items], as lowercase hex, by id; items
  /// that cannot be read are left out.
  ///
  /// Android-only helper used by `AndroidMediaSource.contentHashes`. Runs
  /// on its own native thread, apart from the other MediaStore queries.
  Future<Map<String, String>> contentHashes(List<MediaItem> items) async {
    if (items.isEmpty) return const {};
    final hashes = await _channel.invokeMapMethod<String, String>(
      'contentHashes',
      {'items': _encode(items)},
    );
    return hashes ?? const {};
  }

  /// Location of [items] read from their file headers, by id; items
  /// without one are left out. Fails with a `permission` error without
  /// `ACCESS_MEDIA_LOCATION`.
  ///
  /// Android-only helper used by `AndroidMediaSource.locations`.
  Future<Map<String, GeoPoint>> locations(List<MediaItem> items) async {
    if (items.isEmpty) return const {};
    final reply = await _channel.invokeMapMethod<String, List<Object?>>(
      'locations',
      {'items': _encode(items)},
    );
    return {
      for (final MapEntry(:key, :value) in (reply ?? const {}).entries)
        key: (
          latitude: (value[0]! as num).toDouble(),
          longitude: (value[1]! as num).toDouble(),
        ),
    };
  }

  /// Grayscale thumbnails of the photos with MediaStore [ids], fitting in
  /// [side] × [side] pixels, by id; photos without a readable thumbnail
  /// are left out.
  ///
  /// Android-only helper used by `AndroidMediaSource.grayThumbnails`. Runs
  /// on the hashing thread, after any content hashes in progress.
  Future<Map<String, GrayImage>> grayThumbnails(
    List<String> ids, {
    required int side,
  }) async {
    if (ids.isEmpty) return const {};
    final reply = await _channel.invokeMapMethod<String, Object?>(
      'grayThumbnails',
      {'ids': ids, 'side': side},
    );
    return {
      for (final MapEntry(:key, :value) in (reply ?? const {}).entries)
        if (value case final Map<Object?, Object?> image)
          key: GrayImage(
            width: image['width']! as int,
            height: image['height']! as int,
            pixels: image['pixels']! as Uint8List,
          ),
    };
  }

  /// Raw RGBA pixels of MediaStore item [id], fitting in [width] × [height],
  /// read from MediaStore's thumbnail cache, or decoded from the file with
  /// [fromFile].
  ///
  /// Android-only helper used by the thumbnail and preview providers.
  /// Throws a [PlatformException] with code `not_found` or `dropped` (the
  /// request waited too long behind newer ones).
  Future<RawImageData> thumbnail(
    String id, {
    required bool isVideo,
    required int width,
    required int height,
    bool fromFile = false,
  }) async {
    final reply = await _channel.invokeMapMethod<String, Object>('thumbnail', {
      'id': id,
      'video': isVideo,
      'width': width,
      'height': height,
      'fromFile': fromFile,
    });
    if (reply == null) throw StateError('No thumbnail for $id');
    return RawImageData(
      width: reply['width']! as int,
      height: reply['height']! as int,
      rowBytes: reply['rowBytes']! as int,
      pixels: reply['pixels']! as Uint8List,
    );
  }

  @override
  Future<bool> setFavorite(
    List<MediaItem> items, {
    required bool favorite,
  }) async {
    if (items.isEmpty) return true;
    final done = await _channel.invokeMethod<bool>('setFavorite', {
      'items': _encode(items),
      'favorite': favorite,
    });
    return done ?? false;
  }

  @override
  Future<bool> deletePermanently(List<MediaItem> items) async {
    if (items.isEmpty) return true;
    final done = await _channel.invokeMethod<bool>('deleteMedia', {
      'items': _encode(items),
    });
    return done ?? false;
  }

  @override
  Future<void> share(
    List<MediaItem> items, {
    required bool removeLocation,
  }) async {
    if (items.isEmpty) return;
    await _channel.invokeMethod<void>('share', {
      'items': _encode(items),
      'removeLocation': removeLocation,
    });
  }

  @override
  Future<bool> openMap(double latitude, double longitude) async {
    final opened = await _channel.invokeMethod<bool>('openMap', {
      'latitude': latitude,
      'longitude': longitude,
    });
    return opened ?? false;
  }

  /// Items as the native side expects them.
  List<Map<String, Object?>> _encode(List<MediaItem> items) => [
    for (final item in items)
      {'id': item.id, 'video': item.isVideo, 'mimeType': item.mimeType},
  ];

  @override
  Future<int> sdkVersion() async {
    final version = await _channel.invokeMethod<int>('sdkVersion');
    return version ?? 0;
  }
}

/// Uncompressed RGBA 8888 image returned by the native side.
final class RawImageData {
  /// Creates the image data.
  const RawImageData({
    required this.width,
    required this.height,
    required this.rowBytes,
    required this.pixels,
  });

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Bytes per row, at least `width * 4`.
  final int rowBytes;

  /// Pixels, row by row.
  final Uint8List pixels;
}
