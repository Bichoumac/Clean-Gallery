# Changelog

All notable changes to this project are documented here, one section per milestone. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Last updated: 2026-10-25 — Milestone M1

## [Unreleased]

## [M1] — 2026-10-25 — Navigation

### Added

- Photos and Videos timelines with "Today", "Yesterday", date or month headers, loading the library by chunks of 1,000 ([docs/features/library.md](docs/features/library.md)).
- Edge-to-edge grid with pinch-to-zoom (2 to 6 columns), duration badges on videos and hearts on favorites.
- Albums tab: All media, Favorites (synced with MediaStore `IS_FAVORITE`), device folders; album pages.
- Access prompt, limited-access banner, empty, error and skeleton loading states; pull-to-refresh.
- Full-screen viewer: swipe, Hero transition, pinch and double-tap zoom, tap to hide controls ([docs/features/viewer.md](docs/features/viewer.md)).
- Video playback with own controls: play/pause/replay, seek, mute, rotate.
- `MediaSource` interface and `AndroidMediaSource` on `photo_manager` 3.12, with own thumbnail and full-image providers ([ADR 0009](docs/decisions/0009-media-access.md)).
- `video_player` 2.14 ([ADR 0011](docs/decisions/0011-video-playback.md)); zoom with Flutter's `InteractiveViewer` instead of `photo_view` ([ADR 0010](docs/decisions/0010-photo-zoom.md)).
- Shared media layer in `lib/core/media/`.
- Sorting (date, name, size, duration, both directions) and date filter (presets and custom range) in every timeline, done by MediaStore ([ADR 0012](docs/decisions/0012-sort-and-date-filter.md)).
- Tests: timeline grouping, chunked loading, library and viewer widget tests, pinch gesture, sorting and date filter; shared `pumpTestApp` helper on a phone-sized screen (55 tests).

## [M0] — 2026-10-25 — Foundations

### Added

- Flutter 3.47.8 project for Android only, `minSdk 30`, `targetSdk 36`, `compileSdk 37`.
- Android toolchain AGP 9.4.1 and Gradle 9.6.0 (template: 9.1.0 and 9.3.1), required by `permission_handler` 13 ([ADR 0007](docs/decisions/0007-android-toolchain.md)).
- Gradle heap limited to 3 GB so builds fit on 8 GB machines.
- Manual device verification checklist in [docs/testing.md](docs/testing.md#manual-verification-on-a-device).
- Strict lints with `very_good_analysis`.
- Layered architecture: `analysis`, `domain`, `core`, `platform`, `features`.
- go_router navigation with an onboarding redirect.
- Drift database, schema version 1, with all tables from the specification and a migration strategy.
- Kotlin MethodChannel `clean_gallery/platform`: "Media management" status, settings shortcut, SDK version.
- Platform interfaces `PlatformBridge` and `PermissionService` with Android implementations.
- Onboarding: privacy promise, media access (including Android 14+ partial access), GPS metadata access, optional "Media management".
- English and French localization.
- Build configuration: Google test ad IDs in debug; production IDs from `--dart-define` and the `admobAppId` Gradle property.
- Stats tab layout: reclaimable space and the four cleanup categories (values arrive in M5).
- Tests: database, settings, onboarding, navigation (with a 48 dp touch target check), architecture rules.
- GitHub Actions CI: formatting, analysis, tests, APK and AAB builds, Markdown lint and link check.
- Documentation skeleton and ADRs 0001 to 0008.

### Changed

- After the first phone test: five icon-only tabs (Photos, Videos, Albums, Stats, Settings) in a small floating bar, replacing Photos · Folders · Clean ([ADR 0008](docs/decisions/0008-navigation-and-visual-identity.md)).
- Own visual identity: ink/paper palette with a lime accent, bundled Manrope typeface, no shadows, replacing Material You colors ([docs/design.md](docs/design.md)).
- Ad placements moved to the Albums tab (banner) and the Stats tab (native card).

### Removed

- `dynamic_color`.
