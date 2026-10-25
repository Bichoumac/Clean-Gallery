import 'dart:ui' as ui;

import 'package:clean_gallery/platform/android/android_platform_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:photo_manager/photo_manager.dart';

/// Image of a MediaStore item from MediaStore's own thumbnail cache, at
/// about [width] × [height] pixels: square-ish grid thumbnails or
/// screen-sized previews.
///
/// The native side returns raw RGBA pixels, so nothing is encoded or
/// decoded as JPEG on the way. Two providers are equal when they show the
/// same version of the same item at the same size, so Flutter's image cache
/// reuses them while scrolling.
@immutable
final class NativeThumbnailProvider
    extends ImageProvider<NativeThumbnailProvider> {
  /// Creates a provider for the item [id] modified at [modifiedSecond].
  const NativeThumbnailProvider(
    this.bridge, {
    required this.id,
    required this.isVideo,
    required this.modifiedSecond,
    required this.width,
    required this.height,
  });

  /// Channel to the native loader. Not part of equality.
  final AndroidPlatformBridge bridge;

  /// MediaStore id.
  final String id;

  /// Whether the item is a video (it lives in another MediaStore table).
  final bool isVideo;

  /// Modification time, so an edited item gets a new image.
  final int modifiedSecond;

  /// Requested width in pixels.
  final int width;

  /// Requested height in pixels.
  final int height;

  @override
  Future<NativeThumbnailProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    NativeThumbnailProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_load(key));
  }

  Future<ImageInfo> _load(NativeThumbnailProvider key) async {
    final data = await key.bridge.thumbnail(
      key.id,
      isVideo: key.isVideo,
      width: key.width,
      height: key.height,
    );
    final buffer = await ui.ImmutableBuffer.fromUint8List(data.pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: data.width,
      height: data.height,
      rowBytes: data.rowBytes,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    descriptor.dispose();
    buffer.dispose();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) =>
      other is NativeThumbnailProvider &&
      other.id == id &&
      other.modifiedSecond == modifiedSecond &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(id, modifiedSecond, width, height);
}

/// Full-resolution image of a MediaStore asset, read from its file and
/// decoded at most [maxDimension] pixels on the longest side.
@immutable
final class AssetFullImageProvider
    extends ImageProvider<AssetFullImageProvider> {
  /// Creates a provider for [asset].
  const AssetFullImageProvider(this.asset, {required this.maxDimension});

  /// Asset to render.
  final AssetEntity asset;

  /// Upper bound of the decoded size, in pixels.
  final int maxDimension;

  @override
  Future<AssetFullImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    AssetFullImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_load(key, decode));
  }

  Future<ImageInfo> _load(
    AssetFullImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final file = await key.asset.file;
    if (file == null) {
      throw StateError('No file for asset ${key.asset.id}');
    }
    final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
    final codec = await decode(
      buffer,
      getTargetSize: (width, height) {
        final longest = width > height ? width : height;
        if (longest <= key.maxDimension) {
          return ui.TargetImageSize(width: width, height: height);
        }
        final scale = key.maxDimension / longest;
        return ui.TargetImageSize(
          width: (width * scale).round(),
          height: (height * scale).round(),
        );
      },
    );
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) =>
      other is AssetFullImageProvider &&
      other.asset.id == asset.id &&
      other.asset.modifiedDateSecond == asset.modifiedDateSecond &&
      other.maxDimension == maxDimension;

  @override
  int get hashCode =>
      Object.hash(asset.id, asset.modifiedDateSecond, maxDimension);
}
