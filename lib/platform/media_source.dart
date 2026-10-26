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
  /// Virtual albums ("All media", "Favorites") are not included. Items whose
  /// id is in [hidden] (the app trash) are neither counted nor used as
  /// covers.
  Future<List<Album>> albums({Set<String> hidden = const {}});

  /// Number of items in [selection], leaving out [hidden] ids.
  Future<int> count(MediaSelection selection, {Set<String> hidden = const {}});

  /// Items `[start, end)` of [selection] in its sort order, leaving out
  /// [hidden] ids.
  Future<List<MediaItem>> load(
    MediaSelection selection, {
    required int start,
    required int end,
    Set<String> hidden = const {},
  });

  /// Small square thumbnail of [item], about [size] pixels wide.
  ImageProvider thumbnail(MediaItem item, {required int size});

  /// Screen-sized image of [item], at most [longestSide] pixels on its
  /// longest side, keeping its proportions.
  ///
  /// Rendered by the platform's thumbnail pipeline, so it is much faster
  /// than [fullImage]; the viewer shows it first and loads [fullImage] only
  /// when the user zooms in.
  ImageProvider preview(MediaItem item, {required int longestSide});

  /// Full-resolution image of [item], decoded at most [maxDimension] pixels
  /// on its longest side to bound memory use.
  ImageProvider fullImage(MediaItem item, {int maxDimension = 4096});

  /// Playable URI of a video (a `content://` URI on Android), or `null` if
  /// it cannot be resolved.
  Future<Uri?> videoUri(MediaItem item);
}
