import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:flutter/widgets.dart';

/// Read access to the device's photos and videos.
///
/// The Android implementation uses `photo_manager` (MediaStore). Lists are
/// sorted newest first. Image loading goes through [ImageProvider]s so that
/// Flutter's image cache handles memory and reuse.
abstract interface class MediaSource {
  /// Device folders that contain at least one photo or video, largest first.
  ///
  /// Virtual albums ("All media", "Favorites") are not included.
  Future<List<Album>> albums();

  /// Number of items in [selection].
  Future<int> count(MediaSelection selection);

  /// Items `[start, end)` of [selection], newest first.
  Future<List<MediaItem>> load(
    MediaSelection selection, {
    required int start,
    required int end,
  });

  /// Small square thumbnail of [item], about [size] pixels wide.
  ImageProvider thumbnail(MediaItem item, {required int size});

  /// Full-screen image of [item], decoded at most [maxDimension] pixels on
  /// its longest side to bound memory use.
  ImageProvider fullImage(MediaItem item, {int maxDimension = 4096});

  /// Playable URI of a video (a `content://` URI on Android), or `null` if
  /// it cannot be resolved.
  Future<Uri?> videoUri(MediaItem item);
}
