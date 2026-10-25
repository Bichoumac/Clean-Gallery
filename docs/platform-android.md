# Android platform

Android-specific configuration: SDK levels, permissions and the native Kotlin MethodChannel. Everything here is reached from Dart through interfaces in `lib/platform/`, so the rest of the app stays platform-agnostic.

Last updated: 2026-10-25 — Milestone M2

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

**Never declared:** `MANAGE_EXTERNAL_STORAGE`. A test fails if it appears in a manifest.

Runtime requests go through `PermissionService` ([interface](../lib/platform/permission_service.dart), [Android implementation](../lib/platform/android/android_permission_service.dart)), built on `permission_handler`. `MANAGE_MEDIA` is a special app access, not a runtime permission, so it goes through the native channel below.

### Partial access (Android 14+)

When the user chooses "Select photos" in the system prompt, `permission_handler` reports the photo permission as `limited`. `PermissionService` maps that to `MediaAccess.limited`; onboarding then explains it and offers a button to the app's settings to grant full access.

## Media access

`AndroidMediaSource` ([android_media_source.dart](../lib/platform/android/android_media_source.dart)) implements `MediaSource` with `photo_manager` 3.12 ([ADR 0009](decisions/0009-media-access.md)).

Every query is a custom SQL filter built from the `MediaSelection` ([ADR 0012](decisions/0012-sort-and-date-filter.md)):

| Part | SQL |
| --- | --- |
| Photos / Videos / both | `media_type = 1` / `media_type = 3` / `media_type IN (1, 3)` |
| Favorites | `AND is_favorite = 1` (Android 11+ column) |
| Capture date | `CASE WHEN datetaken > 0 THEN datetaken / 1000 ELSE date_added END` (seconds), as `photo_manager` computes `createDateTime` |
| Date range | `AND <capture date> >= start AND <capture date> < end` |
| Trash (counts, covers, folder summaries) | `AND _id NOT IN (…)`, ids inlined (numbers) to stay clear of SQLite's 999-parameter limit on Android 11. Timelines filter trashed items in memory instead. |
| Sort | `<capture date>`, `LOWER(_display_name)`, `_size` or `duration`, then capture date (newest first) and `_id` as tie-breakers |
| Folder | The `photo_manager` path with that id (a MediaStore bucket), with the same filter. Folder paths are listed once per filter and cached until the Albums tab reloads. |

`photo_manager` drops its media-type condition when a custom `where` is given, so the app always writes it.

- File names come from `DISPLAY_NAME` (`needTitle: true`).
- `photo_manager`'s own permission check is disabled; permissions are handled by `PermissionService`.
- Thumbnails and viewer previews come from the `thumbnail` channel method (below), not from `photo_manager`: MediaStore's own thumbnail cache, raw pixels, newest request first.
- Grid thumbnails are requested with their short side at 256 px (512 px at 2–3 columns), so the square crop is never upscaled; previews at the screen's size (at most 2,560 px).
- Full images are decoded from the file, at most 4,096 px on the longest side, only when zooming in.
- File sizes come from the `mediaSizes` channel method (below), one query per chunk.
- Videos play from `getMediaUrl()`, a `content://` URI given to `video_player`.
- `photo_manager`'s manifest only adds `READ_EXTERNAL_STORAGE` up to Android 12, like ours.

## Native channel `clean_gallery/platform`

Kotlin side: [MainActivity.kt](../android/app/src/main/kotlin/com/bichoumac/clean_gallery/MainActivity.kt). Dart side: [android_platform_bridge.dart](../lib/platform/android/android_platform_bridge.dart), implementing [PlatformBridge](../lib/platform/platform_bridge.dart).

| Method | Arguments | Returns | Errors | Notes |
| --- | --- | --- | --- | --- |
| `isMediaManagementGranted` | none | `bool` | none | `MediaStore.canManageMedia`; always `false` below Android 12. |
| `openMediaManagementSettings` | none | `null` | none | Opens `Settings.ACTION_REQUEST_MANAGE_MEDIA` for this package. No-op below Android 12 or if no activity handles the intent. |
| `sdkVersion` | none | `int` | none | `Build.VERSION.SDK_INT`. |
| `thumbnail` | `id`: `String`, `video`: `bool`, `width`, `height`: `int` | `{width, height, rowBytes, pixels}`, `pixels` RGBA 8888 | `not_found` (unreadable item), `dropped` (waited behind 200 newer requests), `bad_arguments` | `ContentResolver.loadThumbnail` (MediaStore's thumbnail cache, shared with the system gallery), on 4 worker threads, **last in, first out**: what is on screen loads before what was scrolled past. Implemented in [ThumbnailLoader.kt](../android/app/src/main/kotlin/com/bichoumac/clean_gallery/ThumbnailLoader.kt). |
| `albumSummaries` | `excluded`: `List<int>` (trashed ids) | `List` of `{id, name, count, coverId, coverIsVideo, coverWidth, coverHeight, coverModified}`, largest folder first | `permission` | One pass over MediaStore (images and videos, newest first) grouping by `BUCKET_ID`, the folder id `photo_manager` also uses. The first item met in each folder is its cover. Replaces one count call and one path listing per folder in the Albums tab. |
| `setFavorite` | `items`: `List<{id, video, mimeType}>`, `favorite`: `bool` | `bool`: applied (`false` if declined) | `busy` (another request open), `request_failed` | `MediaStore.createFavoriteRequest` for the whole batch, launched with `startIntentSenderForResult`; the result arrives in `onActivityResult`. Implemented in [MediaActions.kt](../android/app/src/main/kotlin/com/bichoumac/clean_gallery/MediaActions.kt). |
| `deleteMedia` | `items`: `List<{id, video, mimeType}>` | `bool`: deleted (`false` if declined) | `busy`, `request_failed` | `MediaStore.createDeleteRequest` for the whole batch: one system confirmation, none with "Media management". Only the trash calls it. |
| `share` | `items`: `List<{id, video, mimeType}>`, `removeLocation`: `bool` | `null` once the share sheet is open | `share_failed` | MediaStore URIs, or copies without GPS for photos when `removeLocation` ([sharing.md](features/sharing.md)). |
| `mediaSizes` | `ids`: `List<String>` | `Map<String, int>` (id → bytes) | `permission` if MediaStore refuses | `_SIZE` of each MediaStore item, queried off the main thread by chunks of 500 ids. Missing ids are left out. Used by `AndroidMediaSource` for each chunk of 1,000 items, since `photo_manager` has no file sizes. |

Unknown methods return `notImplemented`, which Dart raises as `MissingPluginException`.

The manifest declares a `<queries>` entry for `android.settings.REQUEST_MANAGE_MEDIA`: since Android 11, `resolveActivity` cannot see system activities without it, and the check would always fail.

### Why not `photo_manager` thumbnails

Measured on the first device test as slow, especially after scrolling far. For each thumbnail, `photo_manager` runs a MediaStore query to find the item, decodes the original with Glide, re-encodes it as JPEG, and its 8-thread queue is first in, first out, so thumbnails scrolled past are served before those on screen. The `thumbnail` method reads MediaStore's existing thumbnail cache, skips the JPEG round trip and serves the newest requests first.

### Manifest additions (M2)

- A `FileProvider` (`${applicationId}.share`) exposing only `cache/share/`, for the copies shared without GPS ([share_paths.xml](../android/app/src/main/res/xml/share_paths.xml)).

### Android dependencies

| Library | Version | Use |
| --- | --- | --- |
| `androidx.exifinterface:exifinterface` | 1.4.2 | Clearing GPS tags of shared copies |
| `androidx.core:core-ktx` | 1.19.1 | `FileProvider` |

## Build configuration

| Value | Source | Default |
| --- | --- | --- |
| AdMob application ID | Gradle property `admobAppId` → manifest placeholder | Google's public test ID |
| Banner ad unit ID | `--dart-define=ADMOB_BANNER_UNIT_ID` | Test ID in debug; empty in release |
| Native ad unit ID | `--dart-define=ADMOB_NATIVE_UNIT_ID` | Test ID in debug; empty in release |

See [app_config.dart](../lib/core/config/app_config.dart). A release build without an ad unit ID keeps ads disabled.
