/// Level of access the user granted to their photos and videos.
enum MediaAccess {
  /// Access to all photos and videos.
  granted,

  /// Android 14+ partial access: only photos the user selected.
  limited,

  /// No access.
  denied,
}

/// Requests and reads the runtime permissions the app needs.
///
/// Mockable in tests; the implementation lives in `platform/android/`.
abstract interface class PermissionService {
  /// Current media access level, without showing any prompt.
  Future<MediaAccess> mediaAccess();

  /// Shows the system prompt for media access and returns the result.
  Future<MediaAccess> requestMediaAccess();

  /// Whether `ACCESS_MEDIA_LOCATION` is granted, without prompting.
  Future<bool> hasLocationAccess();

  /// Requests `ACCESS_MEDIA_LOCATION`, needed to read GPS data from EXIF.
  ///
  /// Returns `true` when granted.
  Future<bool> requestLocationAccess();

  /// Opens the system settings page of this app, so the user can widen a
  /// partial grant or change a denied permission.
  Future<void> openAppSettings();
}
