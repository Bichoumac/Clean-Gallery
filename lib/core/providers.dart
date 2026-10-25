import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/settings_repository.dart';
import 'package:clean_gallery/platform/android/android_media_source.dart';
import 'package:clean_gallery/platform/android/android_permission_service.dart';
import 'package:clean_gallery/platform/android/android_platform_bridge.dart';
import 'package:clean_gallery/platform/media_source.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:clean_gallery/platform/platform_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

/// The app database. Opened once in `main()` and overridden there.
///
/// Tests override it with an in-memory database.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase.open();
  ref.onDispose(database.close);
  return database;
}

/// Typed access to the `settings` table.
@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
}

/// Platform-specific features. Overridden in tests with a fake.
@Riverpod(keepAlive: true)
PlatformBridge platformBridge(Ref ref) => AndroidPlatformBridge();

/// Runtime permissions. Overridden in tests with a fake.
@Riverpod(keepAlive: true)
PermissionService permissionService(Ref ref) => AndroidPermissionService();

/// Photos and videos of the device. Overridden in tests with a fake.
@Riverpod(keepAlive: true)
MediaSource mediaSource(Ref ref) => AndroidMediaSource();

/// Whether onboarding was completed, read from the database before the app
/// starts. `main()` overrides it so the router can pick the first screen
/// synchronously.
@Riverpod(keepAlive: true)
bool initialOnboardingCompleted(Ref ref) {
  throw UnimplementedError(
    'initialOnboardingCompletedProvider must be overridden in main().',
  );
}
