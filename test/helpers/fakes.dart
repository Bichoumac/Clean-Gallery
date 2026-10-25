import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:clean_gallery/platform/platform_bridge.dart';
import 'package:drift/native.dart';

/// Opens a fresh in-memory database for one test.
AppDatabase inMemoryDatabase() => AppDatabase(NativeDatabase.memory());

/// [PermissionService] that returns a fixed result and records calls.
class FakePermissionService implements PermissionService {
  /// Creates a fake whose requests return [result].
  FakePermissionService({this.result = MediaAccess.granted});

  /// Result returned by [requestMediaAccess] and [mediaAccess].
  MediaAccess result;

  /// Number of media access requests.
  int mediaRequests = 0;

  /// Number of location access requests.
  int locationRequests = 0;

  /// Number of times the app settings were opened.
  int settingsOpened = 0;

  @override
  Future<MediaAccess> mediaAccess() async => result;

  @override
  Future<MediaAccess> requestMediaAccess() async {
    mediaRequests++;
    return result;
  }

  @override
  Future<bool> requestLocationAccess() async {
    locationRequests++;
    return true;
  }

  @override
  Future<void> openAppSettings() async => settingsOpened++;
}

/// [PlatformBridge] that records calls instead of talking to Android.
class FakePlatformBridge implements PlatformBridge {
  /// Whether "Media management" is reported as granted.
  bool mediaManagementGranted = false;

  /// Number of times the "Media management" settings were opened.
  int mediaManagementOpened = 0;

  @override
  Future<bool> isMediaManagementGranted() async => mediaManagementGranted;

  @override
  Future<void> openMediaManagementSettings() async => mediaManagementOpened++;

  @override
  Future<int> sdkVersion() async => 34;
}
