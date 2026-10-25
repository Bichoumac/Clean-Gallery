# Android platform

Android-specific configuration: SDK levels, permissions and the native Kotlin MethodChannel. Everything here is reached from Dart through interfaces in `lib/platform/`, so the rest of the app stays platform-agnostic.

Last updated: 2026-10-25 — Milestone M0

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

## Native channel `clean_gallery/platform`

Kotlin side: [MainActivity.kt](../android/app/src/main/kotlin/com/bichoumac/clean_gallery/MainActivity.kt). Dart side: [android_platform_bridge.dart](../lib/platform/android/android_platform_bridge.dart), implementing [PlatformBridge](../lib/platform/platform_bridge.dart).

| Method | Arguments | Returns | Errors | Notes |
| --- | --- | --- | --- | --- |
| `isMediaManagementGranted` | none | `bool` | none | `MediaStore.canManageMedia`; always `false` below Android 12. |
| `openMediaManagementSettings` | none | `null` | none | Opens `Settings.ACTION_REQUEST_MANAGE_MEDIA` for this package. No-op below Android 12 or if no activity handles the intent. |
| `sdkVersion` | none | `int` | none | `Build.VERSION.SDK_INT`. |

Unknown methods return `notImplemented`, which Dart raises as `MissingPluginException`.

The manifest declares a `<queries>` entry for `android.settings.REQUEST_MANAGE_MEDIA`: since Android 11, `resolveActivity` cannot see system activities without it, and the check would always fail.

### Planned methods

Added in the milestone that needs them, and documented here at that time:

| Method | Milestone |
| --- | --- |
| Favorite write (`IS_FAVORITE`, `createFavoriteRequest`) | M2 |
| Delete request (`createDeleteRequest`) | M2 |
| Copy without GPS for sharing (`ExifInterface`) | M2 |

## Build configuration

| Value | Source | Default |
| --- | --- | --- |
| AdMob application ID | Gradle property `admobAppId` → manifest placeholder | Google's public test ID |
| Banner ad unit ID | `--dart-define=ADMOB_BANNER_UNIT_ID` | Test ID in debug; empty in release |
| Native ad unit ID | `--dart-define=ADMOB_NATIVE_UNIT_ID` | Test ID in debug; empty in release |

See [app_config.dart](../lib/core/config/app_config.dart). A release build without an ad unit ID keeps ads disabled.
