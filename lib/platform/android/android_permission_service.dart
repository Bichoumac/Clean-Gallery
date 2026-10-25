import 'package:clean_gallery/platform/permission_service.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Android implementation of [PermissionService] built on `permission_handler`.
///
/// `permission_handler` maps [ph.Permission.photos] and [ph.Permission.videos]
/// to `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` on Android 13+, and to
/// `READ_EXTERNAL_STORAGE` on Android 11 and 12.
final class AndroidPermissionService implements PermissionService {
  @override
  Future<MediaAccess> mediaAccess() async {
    final photos = await ph.Permission.photos.status;
    final videos = await ph.Permission.videos.status;
    return _combine(photos, videos);
  }

  @override
  Future<MediaAccess> requestMediaAccess() async {
    final statuses = await [
      ph.Permission.photos,
      ph.Permission.videos,
    ].request();
    return _combine(
      statuses[ph.Permission.photos] ?? ph.PermissionStatus.denied,
      statuses[ph.Permission.videos] ?? ph.PermissionStatus.denied,
    );
  }

  @override
  Future<bool> requestLocationAccess() async {
    final status = await ph.Permission.accessMediaLocation.request();
    return status.isGranted;
  }

  @override
  Future<void> openAppSettings() => ph.openAppSettings();

  /// Reduces the photo and video statuses to one [MediaAccess] value.
  ///
  /// Both must be granted for [MediaAccess.granted]. A limited photo grant
  /// (Android 14+ partial access) is reported as [MediaAccess.limited].
  MediaAccess _combine(ph.PermissionStatus photos, ph.PermissionStatus videos) {
    if (photos.isGranted && videos.isGranted) {
      return MediaAccess.granted;
    }
    if (photos.isLimited || videos.isLimited) {
      return MediaAccess.limited;
    }
    return MediaAccess.denied;
  }
}
