# Changelog

All notable changes to this project are documented here, one section per milestone. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Last updated: 2026-10-25 — Milestone M2

## [Unreleased]

## [M2] — 2026-10-25 — Actions

### Added

- App trash: every delete goes through it with *Undo*; Trash page under Albums with days left, restore, delete for good, empty trash; expired items offered once a day at launch or resume, silently deleted with Media management ([docs/features/trash.md](docs/features/trash.md), [ADR 0013](docs/decisions/0013-trash-purge-without-background-job.md)).
- Trashed items hidden from every list, count and cover, directly in the MediaStore queries.
- System favorites (`createFavoriteRequest`) from the viewer and selections ([docs/features/favorites.md](docs/features/favorites.md)).
- Sharing through native intents with MediaStore URIs; GPS removed from photo copies by default (ExifInterface, or JPEG re-encode for HEIC) ([docs/features/sharing.md](docs/features/sharing.md), [ADR 0014](docs/decisions/0014-native-sharing.md)).
- Multi-select: long press, drag-to-select with auto-scroll, selection bar replacing the navigation bar.
- Viewer actions: share, favorite, move to trash.
- Settings tab: theme, language, default columns, trash retention, location on share, permission statuses ([docs/features/settings.md](docs/features/settings.md)).
- Settings read before the first frame; sort of each timeline saved across launches.
- Native channel methods `setFavorite`, `deleteMedia`, `share`; `albumSummaries` skips trashed items.
- Android dependencies `androidx.exifinterface` 1.4.2 and `androidx.core` 1.19.1; `FileProvider` for shared copies.
- Tests: trash repository, settings, trash flows, selection, settings screen; `testApp` helper that closes Drift streams (99 tests).

### Fixed

- Fast-scroll thumb now jumps under the finger at once (the grid's long press competes for the same pointer).

## [M1] — 2026-10-25 — Navigation

### Added

- Photos and Videos timelines with "Today", "Yesterday", date or month headers, loading the library by chunks of 1,000 ([docs/features/library.md](docs/features/library.md)).
- Edge-to-edge grid with pinch-to-zoom (2 to 6 columns), duration badges on videos and hearts on favorites.
- Albums tab: All media, Favorites (synced with MediaStore `IS_FAVORITE`), device folders; album pages.
- Access prompt, limited-access banner, empty, error and skeleton loading states; pull-to-refresh.
- Full-screen viewer: swipe, Hero transition, pinch and double-tap zoom, tap to hide controls ([docs/features/viewer.md](docs/features/viewer.md)).
- Video playback with own controls: play/pause/replay, seek, mute, rotate.
- `MediaSource` interface and `AndroidMediaSource` on `photo_manager` 3.12, with own thumbnail and full-image providers ([ADR 0009](docs/decisions/0009-media-access.md)).
- `video_player` 2.14 ([ADR 0011](docs/decisions/0011-video-playback.md)); own zoom gestures instead of `photo_view` ([ADR 0010](docs/decisions/0010-photo-zoom.md)), so one finger swipes between photos and two fingers zoom.
- Shared media layer in `lib/core/media/`.
- Sorting (date, name, size, duration, both directions) and date filter (presets and custom range) in every timeline, done by MediaStore ([ADR 0012](docs/decisions/0012-sort-and-date-filter.md)).
- Fast-scroll thumb with a bubble showing the month, size, duration or first letter.
- File sizes from MediaStore through the new `mediaSizes` channel method.
- Native thumbnail loader (`thumbnail` channel method): MediaStore's thumbnail cache, raw pixels, newest request first; used for grid thumbnails and viewer previews instead of `photo_manager`'s Glide pipeline.
- Video progress bar follows the finger and seeks on release; fixed it being drawn in the middle of the screen.
- Albums tab: folders, counts and covers from one native query (`albumSummaries`); folder paths cached for album pages.
- Viewer: screen-sized previews first, full resolution only when zooming in; neighbors precached.
- Grid: fixed-height rows (`SliverVariedExtentList`), one-screen prefetch, larger image cache.
- Tests: timeline grouping, chunked loading, library and viewer widget tests, pinch gesture, sorting and date filter, fast scroller, viewer gestures; shared `pumpTestApp` helper on a phone-sized screen (68 tests).

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
