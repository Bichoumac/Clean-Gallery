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

  /// File sizes in bytes of the MediaStore items with the given [ids].
  ///
  /// Android-only helper used by `AndroidMediaSource`: `photo_manager` does
  /// not expose file sizes. Items that no longer exist are left out.
  Future<Map<String, int>> mediaSizes(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final sizes = await _channel.invokeMapMethod<String, int>('mediaSizes', {
      'ids': ids,
    });
    return sizes ?? const {};
  }

  /// Folders containing photos or videos, largest first, each with its item
  /// count and newest item, from one pass over MediaStore.
  ///
  /// Android-only helper used by `AndroidMediaSource.albums`. Each map has
  /// `id`, `name`, `count`, `coverId`, `coverIsVideo`, `coverWidth`,
  /// `coverHeight` and `coverModified` (seconds).
  ///
  /// Items whose id is in [excluded] (the app trash) are skipped.
  Future<List<Map<String, Object?>>> albumSummaries({
    List<int> excluded = const [],
  }) async {
    final list = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'albumSummaries',
      {'excluded': excluded},
    );
    return [
      for (final entry in list ?? const <Map<Object?, Object?>>[])
        entry.cast<String, Object?>(),
    ];
  }

  /// Raw RGBA pixels of MediaStore item [id], fitting in [width] × [height],
  /// read from MediaStore's thumbnail cache.
  ///
  /// Android-only helper used by the thumbnail and preview providers.
  /// Throws a [PlatformException] with code `not_found` or `dropped` (the
  /// request waited too long behind newer ones).
  Future<RawImageData> thumbnail(
    String id, {
    required bool isVideo,
    required int width,
    required int height,
  }) async {
    final reply = await _channel.invokeMapMethod<String, Object>('thumbnail', {
      'id': id,
      'video': isVideo,
      'width': width,
      'height': height,
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
