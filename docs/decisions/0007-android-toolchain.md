# ADR 0007 — Android toolchain: AGP 9.4.1, Gradle 9.6.0, `compileSdk 37`

Why the Android build uses newer AGP and Gradle versions than the Flutter template, and how much memory Gradle gets.

Last updated: 2026-10-25 — Milestone M0

- **Status**: Accepted
- **Date**: 2026-10-25

## Context

`flutter create` (Flutter 3.47.8) generates a project with Android Gradle Plugin 9.1.0, Gradle 9.3.1 and Flutter's default `compileSdk`.

`permission_handler_android` 14.x (pulled by `permission_handler` 13.0.2) compiles against API 37 and states in its changelog that the app must set `compileSdk 37` too. With AGP 9.1.0, the build fails with `Failed to find target with hash string 'android-37'`: AGP 9.1.0 predates API 37, whose SDK package is named `android-37.0`.

## Decision

| Component | Template | Project | File |
| --- | --- | --- | --- |
| Android Gradle Plugin | 9.1.0 | **9.4.1** (latest stable) | [settings.gradle.kts](../../android/settings.gradle.kts) |
| Gradle | 9.3.1 | **9.6.0** (minimum for AGP 9.4.1) | [gradle-wrapper.properties](../../android/gradle/wrapper/gradle-wrapper.properties) |
| `compileSdk` | Flutter default | **37** | [app/build.gradle.kts](../../android/app/build.gradle.kts) |
| Gradle heap | `-Xmx8G` | **`-Xmx3G`**, Kotlin daemon `-Xmx1G` | [gradle.properties](../../android/gradle.properties) |

`targetSdk` stays at 36 (see [platform-android.md](../platform-android.md#sdk-levels)): `compileSdk` only sets which APIs the code can compile against.

The template's `-Xmx8G` got the Gradle daemon killed by the kernel (out of memory) on the 8 GB development machine. 3 GB is enough for this project and fits CI runners.

## Alternatives considered

- **Downgrade to `permission_handler` 12.x** (`permission_handler_android` 13.x, `compileSdk 35`): keeps the template toolchain, but uses a 2025 release and loses a 14.1.0 fix for permissions reset to "Ask every time". Kept as the fallback if Flutter's Gradle plugin turns out to be incompatible with AGP 9.4.
- **Replace `permission_handler` with native Kotlin code**: no dependency, but more code to write and test for a solved problem.

## Consequences

- The debug APK builds with this toolchain (verified 2026-10-25). The release build and CI have not run yet.
- AGP 9.4.1 is newer than what Flutter 3.47.8 was tested with. If `flutter build` warns about the AGP version or fails after a Flutter upgrade, check Flutter's supported AGP range first.
- When Flutter's template catches up, align with it again and update this ADR.
