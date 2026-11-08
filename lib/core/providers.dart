import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/duplicate_repository.dart';
import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/core/database/memory_repository.dart';
import 'package:clean_gallery/core/database/settings_repository.dart';
import 'package:clean_gallery/core/database/slideshow_repository.dart';
import 'package:clean_gallery/core/database/swipe_repository.dart';
import 'package:clean_gallery/core/database/trash_repository.dart';
import 'package:clean_gallery/core/database/user_album_repository.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/memory.dart';
import 'package:clean_gallery/domain/ritual.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:clean_gallery/domain/trashed_item.dart';
import 'package:clean_gallery/platform/android/android_media_source.dart';
import 'package:clean_gallery/platform/android/android_music_player.dart';
import 'package:clean_gallery/platform/android/android_permission_service.dart';
import 'package:clean_gallery/platform/android/android_platform_bridge.dart';
import 'package:clean_gallery/platform/android/android_reminder_service.dart';
import 'package:clean_gallery/platform/media_source.dart';
import 'package:clean_gallery/platform/music_player.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:clean_gallery/platform/platform_bridge.dart';
import 'package:clean_gallery/platform/reminder_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Size of the device's display in physical pixels, or `null` when the
/// platform does not report it. Screenshots are recognized by it.
@Riverpod(keepAlive: true)
({int width, int height})? screenSize(Ref ref) {
  final size = PlatformDispatcher.instance.displays.firstOrNull?.size;
  if (size == null || size.isEmpty) return null;
  return (width: size.width.round(), height: size.height.round());
}

/// The media index stored in the `assets` table, read with the date chosen
/// in Settings.
@Riverpod(keepAlive: true)
MediaIndexRepository mediaIndexRepository(Ref ref) => MediaIndexRepository(
  ref.watch(appDatabaseProvider),
  correctedDates: ref.watch(
    appSettingsControllerProvider.select((s) => s.correctedDates),
  ),
  screen: ref.watch(screenSizeProvider),
);

/// Hashes and groups of the duplicate detection.
@Riverpod(keepAlive: true)
DuplicateRepository duplicateRepository(Ref ref) =>
    DuplicateRepository(ref.watch(appDatabaseProvider));

/// The app trash.
@Riverpod(keepAlive: true)
TrashRepository trashRepository(Ref ref) =>
    TrashRepository(ref.watch(appDatabaseProvider));

/// Decisions of the swipe sessions.
@Riverpod(keepAlive: true)
SwipeRepository swipeRepository(Ref ref) =>
    SwipeRepository(ref.watch(appDatabaseProvider));

/// Albums created by the user.
@Riverpod(keepAlive: true)
UserAlbumRepository userAlbumRepository(Ref ref) => UserAlbumRepository(
  ref.watch(appDatabaseProvider),
  correctedDates: ref.watch(
    appSettingsControllerProvider.select((s) => s.correctedDates),
  ),
);

/// The user's albums with their count and cover, newest album first.
@Riverpod(keepAlive: true)
Stream<List<UserAlbum>> userAlbums(Ref ref) =>
    ref.watch(userAlbumRepositoryProvider).watchAlbums();

/// A number increased each time items are added to or removed from a user
/// album.
@Riverpod(keepAlive: true)
Stream<int> userAlbumItemChanges(Ref ref) =>
    ref.watch(userAlbumRepositoryProvider).watchItemChanges();

/// Slideshows saved by the user.
@Riverpod(keepAlive: true)
SlideshowRepository slideshowRepository(Ref ref) => SlideshowRepository(
  ref.watch(appDatabaseProvider),
  correctedDates: ref.watch(
    appSettingsControllerProvider.select((s) => s.correctedDates),
  ),
);

/// Saved slideshows with their count and cover, newest first.
@Riverpod(keepAlive: true)
Stream<List<SavedSlideshow>> savedSlideshows(Ref ref) =>
    ref.watch(slideshowRepositoryProvider).watchSaved();

/// Memories met so far and rituals.
@Riverpod(keepAlive: true)
MemoryRepository memoryRepository(Ref ref) =>
    MemoryRepository(ref.watch(appDatabaseProvider));

/// Memories not dismissed, most recently found first: the *Memories* list.
@Riverpod(keepAlive: true)
Stream<List<Memory>> storedMemories(Ref ref) =>
    ref.watch(memoryRepositoryProvider).watchMemories();

/// The user's rituals, oldest first.
@Riverpod(keepAlive: true)
Stream<List<Ritual>> rituals(Ref ref) =>
    ref.watch(memoryRepositoryProvider).watchRituals();

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

/// Slideshow music. Overridden in tests with a fake.
@Riverpod(keepAlive: true)
MusicPlayer musicPlayer(Ref ref) => AndroidMusicPlayer();

/// Notifications at set times. Overridden in tests with a fake.
@Riverpod(keepAlive: true)
ReminderService reminderService(Ref ref) => AndroidReminderService();

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
