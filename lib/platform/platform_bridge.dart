import 'dart:typed_data';

import 'package:clean_gallery/domain/media_item.dart';

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

  /// Opens the web page at [url] in the user's browser. Returns `false`
  /// when no app can open it.
  Future<bool> openLink(Uri url);

  /// The installed app's version name, e.g. `1.0.0`.
  Future<String> appVersion();

  /// Saves an edited copy of [photo] as a new JPEG photo in the same
  /// folder, with the same capture date and the original's metadata (EXIF)
  /// except its orientation and size. [rgba] holds [width] × [height]
  /// opaque pixels, 4 bytes each, row by row: the edit already applied.
  /// Returns the new photo's id. The original is not changed.
  Future<String> saveEditedPhoto(
    MediaItem photo, {
    required int width,
    required int height,
    required Uint8List rgba,
  });

  /// Keeps the screen on while [on], e.g. during a slideshow.
  Future<void> setKeepScreenOn({required bool on});

  /// Brightness of the app's window, from 0 to 1: the app's own if set with
  /// [setScreenBrightness], otherwise about the system's.
  Future<double> screenBrightness();

  /// Sets the brightness of the app's window only, from 0 to 1, or gives it
  /// back to the system with `null`. The system setting is not changed.
  Future<void> setScreenBrightness(double? value);

  /// Media volume of the device, from 0 to 1.
  Future<double> mediaVolume();

  /// Sets the device's media volume, from 0 to 1, without the system's
  /// volume panel.
  Future<void> setMediaVolume(double value);
}
