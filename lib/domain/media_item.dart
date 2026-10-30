import 'package:clean_gallery/domain/enums.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_item.freezed.dart';

/// A photo or video from the device library.
///
/// Platform-independent: the Android implementation fills it from MediaStore,
/// a future iOS one from PhotoKit. [id] is the platform's own identifier
/// (the MediaStore id on Android, as a string).
@freezed
abstract class MediaItem with _$MediaItem {
  /// Creates a media item.
  const factory MediaItem({
    /// Platform identifier, stable across launches.
    required String id,

    /// Photo or video.
    required MediaKind kind,

    /// Width in pixels, after orientation is applied.
    required int width,

    /// Height in pixels, after orientation is applied.
    required int height,

    /// When the item was taken, as reported by the platform.
    ///
    /// From M3 the analysis engine resolves a more reliable date (EXIF, file
    /// name) and stores it in the database.
    required DateTime takenAt,

    /// Last modification of the file.
    required DateTime modifiedAt,

    /// Length of a video; [Duration.zero] for photos.
    @Default(Duration.zero) Duration duration,

    /// Whether the item is a favorite in the system gallery.
    @Default(false) bool isFavorite,

    /// File size in bytes; 0 when unknown.
    @Default(0) int sizeBytes,

    /// File name with extension, when known.
    String? fileName,

    /// Folder path relative to the storage root, e.g. `DCIM/Camera/`.
    String? relativePath,

    /// MIME type, e.g. `image/jpeg`.
    String? mimeType,

    /// Sharpness measured by the analysis engine (variance of the
    /// Laplacian on a thumbnail), higher is sharper; `null` until measured
    /// and for videos.
    double? sharpness,

    /// Contrast measured with [sharpness] (standard deviation of the
    /// pixels); tells hazy photos from blurry ones. `null` until measured.
    double? contrast,
  }) = _MediaItem;

  const MediaItem._();

  /// Whether this item is a video.
  bool get isVideo => kind == MediaKind.video;

  /// Width divided by height; 1 when a dimension is unknown.
  double get aspectRatio => width > 0 && height > 0 ? width / height : 1;
}
