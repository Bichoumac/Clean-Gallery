# Android platform

Android-specific configuration: SDK levels, permissions and the native Kotlin MethodChannel. Everything here is reached from Dart through interfaces in `lib/platform/`, so the rest of the app stays platform-agnostic.

Last updated: 2026-11-05 — Milestone M11

## SDK levels

| Setting | Value | Why |
| --- | --- | --- |
| `minSdk` | 30 (Android 11) | Required by the brief; scoped storage and MediaStore write requests are available. See [ADR 0006](decisions/0006-permissions.md). |
| `targetSdk` | 36 | Latest level required by Google Play at the time of writing. Check before each release. |
| `compileSdk` | 37 | Required by `permission_handler_android` 14. See [ADR 0007](decisions/0007-android-toolchain.md). |

Configured in [android/app/build.gradle.kts](../android/app/build.gradle.kts).

## Toolchain

| Component | Version |
| --- | --- |
| Android Gradle Plugin | 9.4.1 |
| Gradle | 9.6.0 |
| Kotlin Gradle plugin | 2.4.0 |
| JDK | 17 |
| Gradle heap | 3 GB (`android/gradle.properties`) |

Newer than the Flutter template; the reasons are in [ADR 0007](decisions/0007-android-toolchain.md).

## Permissions

Declared in [AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml).

| Permission | Android versions | Requested | Purpose |
| --- | --- | --- | --- |
| `READ_MEDIA_IMAGES` | 13+ | Onboarding | Read photos. |
| `READ_MEDIA_VIDEO` | 13+ | Onboarding | Read videos. |
| `READ_MEDIA_VISUAL_USER_SELECTED` | 14+ | Implicitly, by the system picker | Partial access: only photos the user picked. |
| `READ_EXTERNAL_STORAGE` | 11–12 (`maxSdkVersion 32`) | Onboarding | Read media before Android 13. |
| `ACCESS_MEDIA_LOCATION` | 11+ | Onboarding, after media access | Read GPS coordinates from EXIF; otherwise Android strips them. |
| `MANAGE_MEDIA` | 12+ | Optional, from onboarding and settings | "Media management": delete and favorite without a confirmation prompt each time. |
| `POST_NOTIFICATIONS` | 13+ | When the memories notification or a ritual is turned on, never at onboarding | Memory and ritual notifications ([features/memories.md](features/memories.md)). Refused: the memory card still shows. |
| `RECEIVE_BOOT_COMPLETED` | all | Never (normal permission) | Sets the next memory or ritual notification again after a reboot; the receiver reads nothing else ([ADR 0027](decisions/0027-notifications-without-background-work.md)). |
| `INTERNET` | all | Never (normal permission) | Map tiles from OpenStreetMap (M6), its only use. Debug builds had it from M0 for Flutter tooling. No media or metadata is sent ([ADR 0022](decisions/0022-map-tiles-and-grid-clusters.md)). |

**Never declared:** `MANAGE_EXTERNAL_STORAGE`. A test fails if it appears in a manifest.

Runtime requests go through `PermissionService` ([interface](../lib/platform/permission_service.dart), [Android implementation](../lib/platform/android/android_permission_service.dart)), built on `permission_handler`. `MANAGE_MEDIA` is a special app access, not a runtime permission, so it goes through the native channel below.

### Partial access (Android 14+)

When the user chooses "Select photos" in the system prompt, `permission_handler` reports the photo permission as `limited`. `PermissionService` maps that to `MediaAccess.limited`; onboarding then explains it and offers a button to the app's settings to grant full access.

## Media access

`AndroidMediaSource` ([android_media_source.dart](../lib/platform/android/android_media_source.dart)) implements `MediaSource`. Lists do not query MediaStore: they read the media index in the database, which `MediaIndex` fills from two channel methods ([ADR 0015](decisions/0015-persistent-media-index.md)):

| Step | Channel method | MediaStore query |
| --- | --- | --- |
| Snapshot | `mediaSnapshot` | `_ID`, `GENERATION_MODIFIED` of `MEDIA_TYPE IN (1, 3)` on `Files.getContentUri("external")`, newest first |
| Details | `mediaDetails` | 17 columns of the given ids (below), 1,000 ids per query, ids inlined as numbers to stay clear of SQLite's 999-parameter limit on Android 11 |

- **Capture date**: `DATE_TAKEN` (milliseconds) when set, otherwise `DATE_ADDED`, as `photo_manager` computes `createDateTime`; stored as `assets.taken_at`. The snapshot is ordered by it so the newest items are indexed first.
- **Dimensions** are swapped when `ORIENTATION` is 90 or 270, so they match the displayed image.
- **Camera tab**: `relative_path LIKE 'DCIM/Camera/%'`, the camera folder on Samsung and Pixel phones; now an SQLite condition on the index.
- **Folders**: `BUCKET_ID` and `BUCKET_DISPLAY_NAME`, the folder id and name `photo_manager` also uses.
- Pending and system-trashed items are left out by MediaStore's default query on Android 11+.
- `photo_manager` 3.12 ([ADR 0009](decisions/0009-media-access.md)) is now used only for full-resolution files and video URIs. Its own permission check is disabled; permissions are handled by `PermissionService`.
- Thumbnails and viewer previews come from the `thumbnail` channel method (below), as raw pixels, newest request first: thumbnails from MediaStore's own thumbnail cache, previews decoded from the photo file (`fromFile`), since that cache stops at 512 px on Samsung phones.
- Grid thumbnails are requested with their short side at 256 px (512 px at 2–3 columns), so the square crop is never upscaled; previews at the screen's size (at most 2,560 px).
- Full images are decoded from the file, at most 4,096 px on the longest side, only when zooming in.
- Videos play from `getMediaUrl()`, a `content://` URI given to `video_player`.
- `photo_manager`'s manifest only adds `READ_EXTERNAL_STORAGE` up to Android 12, like ours.

## Native channel `clean_gallery/platform`

Kotlin side: [MainActivity.kt](../android/app/src/main/kotlin/com/bichoumac/clean_gallery/MainActivity.kt). Dart side: [android_platform_bridge.dart](../lib/platform/android/android_platform_bridge.dart), implementing [PlatformBridge](../lib/platform/platform_bridge.dart).

Methods run on a worker thread (`mediaSnapshot`, `mediaDetails`, `mediaMetadata`, `locations`, `contentHashes`, `grayThumbnails`, `saveEditedPhoto`) always reply: a revoked permission as `permission`, any other exception as `failed`, so a Dart call never waits forever.

| Method | Arguments | Returns | Errors | Notes |
| --- | --- | --- | --- | --- |
| `isMediaManagementGranted` | none | `bool` | none | `MediaStore.canManageMedia`; always `false` below Android 12. |
| `openMediaManagementSettings` | none | `null` | none | Opens `Settings.ACTION_REQUEST_MANAGE_MEDIA` for this package. No-op below Android 12 or if no activity handles the intent. |
| `sdkVersion` | none | `int` | none | `Build.VERSION.SDK_INT`. |
| `thumbnail` | `id`: `String`, `video`: `bool`, `width`, `height`: `int`, `fromFile`: `bool` | `{width, height, rowBytes, pixels}`, `pixels` RGBA 8888 | `not_found` (unreadable item), `dropped` (waited behind 200 newer requests), `bad_arguments` | `ContentResolver.loadThumbnail` (MediaStore's thumbnail cache, shared with the system gallery); with `fromFile`, a photo is decoded from its file by `ImageDecoder` to the requested longest side instead (viewer previews); for a video MediaStore has no thumbnail for, the cover embedded in the file, then the frame at 10 % of its duration (`MediaMetadataRetriever`). On 4 worker threads, **last in, first out**: what is on screen loads before what was scrolled past. Implemented in [ThumbnailLoader.kt](../android/app/src/main/kotlin/com/bichoumac/clean_gallery/ThumbnailLoader.kt). |
| `mediaSnapshot` | none | `{version: String, ids: long[], revisions: long[]}`, newest first | `permission`, `failed` | `MediaStore.getVersion` and the `_ID` and `GENERATION_MODIFIED` of every photo and video, as two arrays of the same length (Dart `Int64List`). One query, on the worker thread. Implemented in [MediaIndex.kt](../android/app/src/main/kotlin/com/bichoumac/clean_gallery/MediaIndex.kt). |
| `mediaDetails` | `ids`: `List<String>` | `List` of `{id, bucketId, bucketName, relativePath, name, mimeType, video, size, width, height, takenAt, dateTaken, added, modified, duration, favorite, revision}` | `permission`, `failed` | Full metadata of the given items, by chunks of 1,000 ids; missing ids are left out. `width` and `height` follow the orientation; `takenAt` (`DATE_TAKEN` or `DATE_ADDED`), `dateTaken` (raw, 0 when unset) and `duration` in milliseconds, `added` and `modified` in seconds; `revision` is `GENERATION_MODIFIED`. `dateTaken`, `added` and `modified` tell whether the date comes from the file's metadata ([analysis-engine.md](analysis-engine.md#thresholds-and-rationale)). |
| `mediaMetadata` | `id`: `String`, `video`: `bool` | `{make?, model?, lens?, iso?, aperture?, exposure?, focalLength?, focalLength35?, latitude?, longitude?}`; missing values left out | `permission`, `failed`, `bad_arguments` | Photos: `ExifInterface` on the file's stream (header only); `exposure` in seconds, focal lengths in mm, `0, 0` locations dropped. Videos: only the location, from `MediaMetadataRetriever.METADATA_KEY_LOCATION` (ISO 6709). With `ACCESS_MEDIA_LOCATION` granted the URI goes through `MediaStore.setRequireOriginal`, otherwise Android removes the GPS tags. For the viewer's info panel ([viewer.md](features/viewer.md#info-panel)). |
| `locations` | `items`: `List<{id, video, mimeType}>` | `Map<String, [latitude, longitude]>`; items without a location left out | `permission` (also without `ACCESS_MEDIA_LOCATION`), `failed` | EXIF `latLong` of photos, `METADATA_KEY_LOCATION` of videos, through `setRequireOriginal` URIs; `0, 0` counts as none. Headers only. Used by the map ([features/map.md](features/map.md#reading-locations)). |
| `saveEditedPhoto` | `id`: `String` (the original), `width`, `height`: `int`, `rgba`: `Uint8List` (width × height opaque pixels, 4 bytes each, rendered by the editor or the scanner) | `String`: the new photo's id | `bad_arguments`, `permission`, `failed` | `PhotoSaver`: JPEG quality 95 in the original's folder, named `<name>_edited_<time>.jpg`, with its `DATE_TAKEN` and EXIF tags (camera, settings, dates, GPS when readable; orientation normal, new size; software "Clean Gallery"), pending until written; a failed write removes the row. See [features/editor.md](features/editor.md#how-it-works). |
| `openMap` | `latitude`, `longitude`: `double` | `bool`: a map app was opened | `bad_arguments` | Starts `ACTION_VIEW` on `geo:<lat>,<lng>?q=<lat>,<lng>` (a pin at the point); `false` on `ActivityNotFoundException`. On the main thread. From the info panel's location. |
| `contentHashes` | `items`: `List<{id, video, mimeType}>` | `Map<String, String>` (id → SHA-256, lowercase hex) | `permission`, `failed` | Reads each file in full through its Images or Video URI, in 1 MB blocks, on a dedicated thread so it never delays other queries. Unreadable items are left out. Used for exact duplicates ([ADR 0017](decisions/0017-exact-duplicates-sha256.md)). |
| `grayThumbnails` | `ids`: `List<String>` (photos), `side`: `int` (256; 128 until M5) | `Map<String, {width, height, pixels}>`, `pixels` one brightness byte per pixel, row by row | `permission`, `failed` | `ContentResolver.loadThumbnail` at most `side` × `side`, converted to luma (`0.299 R + 0.587 G + 0.114 B`). Started from the hashing thread, after any `contentHashes` call; four threads render the batch. Photos whose thumbnail fails for any reason are left out, the others are returned. Used for similar photos and blurry photos ([ADR 0018](decisions/0018-perceptual-hashes-from-thumbnails.md), [ADR 0020](decisions/0020-blur-and-brightness-with-the-hashes.md)). |
| `setFavorite` | `items`: `List<{id, video, mimeType}>`, `favorite`: `bool` | `bool`: applied (`false` if declined) | `busy` (another request open), `request_failed` | `MediaStore.createFavoriteRequest` for the whole batch, launched with `startIntentSenderForResult`; the result arrives in `onActivityResult`. Implemented in [MediaActions.kt](../android/app/src/main/kotlin/com/bichoumac/clean_gallery/MediaActions.kt). |
| `deleteMedia` | `items`: `List<{id, video, mimeType}>` | `bool`: deleted (`false` if declined) | `busy`, `request_failed` | `MediaStore.createDeleteRequest` for the whole batch: one system confirmation, none with "Media management". Only the trash calls it. |
| `share` | `items`: `List<{id, video, mimeType}>`, `removeLocation`: `bool` | `null` once the share sheet is open | `share_failed` | MediaStore URIs, or copies without GPS for photos when `removeLocation` ([sharing.md](features/sharing.md)). |
| `setKeepScreenOn` | `on`: `bool` | `null` | none | `FLAG_KEEP_SCREEN_ON` on the window, during slideshows. |
| `screenBrightness` | none | `double` | none | The window's own brightness if set, otherwise the system's setting / 255 (approximate). |
| `setScreenBrightness` | `value`: `double?` | `null` | none | `screenBrightness` of the window's attributes, 0.01 to 1; `null` gives it back to the system. Video gestures. |
| `mediaVolume` | none | `double` | none | `STREAM_MUSIC` volume over its maximum. |
| `setMediaVolume` | `value`: `double` | `null` | none | `AudioManager.setStreamVolume` on `STREAM_MUSIC`, without the system panel (flag 0). No permission needed. Video gestures. |
| `musicPlay` | `uri`: `String?` (a picked document) or `asset`: `String?` (a bundled track), `volume`: `double` | `bool`: playing | none | A `MediaPlayer` in a loop, replacing any track; `false` when the file cannot be read (moved, deleted, access lost). [SlideshowMusic.kt](../android/app/src/main/kotlin/com/bichoumac/clean_gallery/SlideshowMusic.kt). |
| `musicPause`, `musicResume`, `musicStop` | none | `null` | none | |
| `musicVolume` | `volume`: `double` 0–1 | `null` | none | The fade-out at the end. |
| `pickMusic` | none | `{uri, name}` or `null` when cancelled | none | `ACTION_OPEN_DOCUMENT` with `audio/*`, then `takePersistableUriPermission` (read): no audio permission, access to that file only. |
| `releaseMusic` | `uri`: `String` | `null` | none | `releasePersistableUriPermission`, once no slideshow uses the track. |
| `scheduleReminders` | `reminders`: `List<{id, at (epoch ms), title, body, payload}>` | `null` | none | Replaces the pending notifications, see below. |
| `canNotify` | none | `bool` | none | `NotificationManagerCompat.areNotificationsEnabled`. |
| `takeReminderPayload` | none | `String?` | none | Payload of the notification that started the app, once. |

Unknown methods return `notImplemented`, which Dart raises as `MissingPluginException`.

The manifest declares a `<queries>` entry for `android.settings.REQUEST_MANAGE_MEDIA`: since Android 11, `resolveActivity` cannot see system activities without it, and the check would always fail.

### Notifications at set times

[Reminders.kt](../android/app/src/main/kotlin/com/bichoumac/clean_gallery/Reminders.kt), behind `ReminderService` ([interface](../lib/platform/reminder_service.dart), [Android implementation](../lib/platform/android/android_reminder_service.dart)); [ADR 0027](decisions/0027-notifications-without-background-work.md).

- `scheduleReminders` stores the list in the app's preferences (`reminders`, JSON) and sets **one inexact alarm** (`AlarmManager.setAndAllowWhileIdle`, `RTC_WAKEUP`) for the earliest. No `SCHEDULE_EXACT_ALARM`: Android may deliver it a few minutes late.
- `ReminderReceiver` (not exported) receives the alarm, `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED`: it shows the notifications due (dropping those more than 6 hours late, e.g. after the phone was off), removes them from the list and sets the alarm for the next one. It reads that list only, never MediaStore or the database; a test checks it.
- Channel `slideshows` ("Memories and slideshows"), default importance, icon [ic_stat_clean_gallery.xml](../android/app/src/main/res/drawable/ic_stat_clean_gallery.xml).
- A tap opens `MainActivity` with the payload as an extra: read by `takeReminderPayload` at launch, or sent to Dart over the **`clean_gallery/reminders`** channel (`reminderTapped`, the payload as argument) when the app runs (`onNewIntent`).

### Why not `photo_manager` thumbnails

Measured on the first device test as slow, especially after scrolling far. For each thumbnail, `photo_manager` runs a MediaStore query to find the item, decodes the original with Glide, re-encodes it as JPEG, and its 8-thread queue is first in, first out, so thumbnails scrolled past are served before those on screen. The `thumbnail` method reads MediaStore's existing thumbnail cache, skips the JPEG round trip and serves the newest requests first.

### Manifest additions

- M9: the `ReminderReceiver` above, and the notification channel name in `res/values*/strings.xml` (English, French).
- M2: a `FileProvider` (`${applicationId}.share`) exposing only `cache/share/`, for the copies shared without GPS ([share_paths.xml](../android/app/src/main/res/xml/share_paths.xml)).

### Android dependencies

| Library | Version | Use |
| --- | --- | --- |
| `androidx.exifinterface:exifinterface` | 1.4.2 | Clearing GPS tags of shared copies |
| `androidx.core:core-ktx` | 1.19.1 | `FileProvider`, `NotificationCompat` |

## Android backup

Android's Auto Backup stays on (`android:allowBackup` is not set), by the product owner's choice on 2026-11-05. If the user has Google backup on, Android may copy the app's internal data to their Google account or a new device, including its settings and database with file names, dates and locations. Photos and videos are not part of it. Albums, saved slideshows and settings can then follow the user to a new phone. The privacy policy says so; any change here must change the policy too.

## Build configuration

The app needs no build-time ID or key: the ads and their AdMob IDs were removed on 2026-11-08 ([ADR 0032](decisions/0032-open-source-without-ads.md)). Release signing comes with M12, from Gradle properties kept out of the repository.
