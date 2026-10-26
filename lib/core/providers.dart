import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/core/database/settings_repository.dart';
import 'package:clean_gallery/core/database/trash_repository.dart';
import 'package:clean_gallery/domain/trashed_item.dart';
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

/// The media index stored in the `assets` table.
@Riverpod(keepAlive: true)
MediaIndexRepository mediaIndexRepository(Ref ref) =>
    MediaIndexRepository(ref.watch(appDatabaseProvider));

/// The app trash.
@Riverpod(keepAlive: true)
TrashRepository trashRepository(Ref ref) =>
    TrashRepository(ref.watch(appDatabaseProvider));

/// Ids of trashed items. Every media list hides them.
@Riverpod(keepAlive: true)
Stream<Set<String>> trashedIds(Ref ref) =>
    ref.watch(trashRepositoryProvider).watchTrashedIds();

/// Trashed items, most recently trashed first.
@Riverpod(keepAlive: true)
Stream<List<TrashedItem>> trashItems(Ref ref) =>
    ref.watch(trashRepositoryProvider).watchItems();

/// Platform-specific features. Overridden in tests with a fake.
@Riverpod(keepAlive: true)
PlatformBridge platformBridge(Ref ref) => AndroidPlatformBridge();

/// Runtime permissions. Overridden in tests with a fake.
@Riverpod(keepAlive: true)
PermissionService permissionService(Ref ref) => AndroidPermissionService();

/// Photos and videos of the device. Overridden in tests with a fake.
@Riverpod(keepAlive: true)
MediaSource mediaSource(Ref ref) => AndroidMediaSource(AndroidPlatformBridge());

/// Whether onboarding was completed, read from the database before the app
/// starts. `main()` overrides it so the router can pick the first screen
/// synchronously.
@Riverpod(keepAlive: true)
bool initialOnboardingCompleted(Ref ref) {
  throw UnimplementedError(
    'initialOnboardingCompletedProvider must be overridden in main().',
  );
}
