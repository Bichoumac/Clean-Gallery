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
}
