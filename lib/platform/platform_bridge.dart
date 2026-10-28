import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/photo_edit.dart';

/// Platform-specific features that the Dart packages do not cover.
///
/// The Android implementation talks to the Kotlin module over a
/// MethodChannel. Keep this interface free of Android types so that an iOS
/// implementation can be added later without touching the UI.
abstract interface class PlatformBridge {
  /// Whether the "Media management" special permission (`MANAGE_MEDIA`) is
  /// granted. Always `false` below Android 12.
  Future<bool> isMediaManagementGranted();

  /// Opens the system screen where the user grants "Media management".
  ///
  /// Does nothing on platforms or Android versions where it is unavailable.
  Future<void> openMediaManagementSettings();

  /// Android SDK version of the running device, e.g. `34`.
  Future<int> sdkVersion();

  /// Marks [items] as favorites, or not, in the system gallery.
  ///
  /// Shows one system confirmation for the whole batch, unless the app has
  /// "Media management". Returns `true` when applied, `false` when the user
  /// declined.
  Future<bool> setFavorite(List<MediaItem> items, {required bool favorite});

  /// Deletes [items] from the device for good.
  ///
  /// Shows one system confirmation for the whole batch, unless the app has
  /// "Media management". Returns `true` when deleted, `false` when the user
  /// declined.
  Future<bool> deletePermanently(List<MediaItem> items);

  /// Opens the system share sheet for [items].
  ///
  /// With [removeLocation], photos are shared as temporary copies without
  /// GPS data; the originals are not changed. Videos are always shared as
  /// they are.
  Future<void> share(List<MediaItem> items, {required bool removeLocation});

  /// Opens a map app at [latitude], [longitude]. Returns `false` when no
  /// app can show a location.
  Future<bool> openMap(double latitude, double longitude);

  /// Saves [photo] with [edit] applied as a new JPEG photo in the same
  /// folder, with the same capture date and the original's metadata (EXIF)
  /// except its orientation and size. [colorMatrix] is the 4 × 5 matrix of
  /// the edit's colors, as previewed. Returns the new photo's id. The
  /// original is not changed.
  Future<String> saveEditedPhoto(
    MediaItem photo,
    PhotoEdit edit, {
    required List<double> colorMatrix,
  });
}
