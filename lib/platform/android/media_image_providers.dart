import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:photo_manager/photo_manager.dart';

/// Thumbnail of a MediaStore asset, rendered by Android at [size] pixels.
///
/// Two providers are equal when they show the same version of the same
/// asset at the same size, so Flutter's image cache reuses decoded
/// thumbnails while scrolling.
@immutable
final class AssetThumbnailProvider
    extends ImageProvider<AssetThumbnailProvider> {
  /// Creates a provider for [asset] at [size] × [size] pixels.
  const AssetThumbnailProvider(this.asset, {required this.size});

  /// Asset to render.
  final AssetEntity asset;

  /// Requested square size in pixels.
  final int size;

  @override
  Future<AssetThumbnailProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    AssetThumbnailProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_load(key, decode));
  }

  Future<ImageInfo> _load(
    AssetThumbnailProvider key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await key.asset.thumbnailDataWithSize(
      ThumbnailSize.square(key.size),
      quality: 85,
    );
    if (bytes == null || bytes.isEmpty) {
      throw StateError('No thumbnail for asset ${key.asset.id}');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) =>
      other is AssetThumbnailProvider &&
      other.asset.id == asset.id &&
      other.asset.modifiedDateSecond == asset.modifiedDateSecond &&
      other.size == size;

  @override
  int get hashCode => Object.hash(asset.id, asset.modifiedDateSecond, size);
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
