# Progress

Status of each milestone, what is done, known issues and next steps. Update this file at the end of every milestone.

Last updated: 2026-10-26 — Milestone M3

## Milestones

| Milestone | Scope | Status |
| --- | --- | --- |
| M0 | Foundations | Merged into `main` (PR #1) |
| M1 | Navigation: timelines, albums, grid, viewer, video, sorting, date filter | Merged into `main` (PR #2) |
| M2 | Actions: favorites, sharing, multi-select, trash, basic settings | Merged into `main` (PR #3) |
| M3 | Engine level 1: indexing, dates, exact duplicates, bursts | In progress on `m3-engine`: media index, capture dates and exact duplicates done |
| M4 | Engine level 2: perceptual hashes, similar photos, dashboard | Not started |
| M5 | Cleanup: Stats values, swipe mode, blurry, screenshots, large videos | Not started |
| M6 | Advanced viewer and editing | Not started |
| M7 | Exploration: map, search | Not started |
| M8 | Monetization | Not started |
| M9 | Polish and release preparation | Not started |

## M3 — Engine level 1

### Done

- **Persistent media index**: every list reads the `assets` table, so the library shows at once at launch; a sync at launch, on return to the foreground and on pull-to-refresh applies only what changed in MediaStore ([ADR 0015](decisions/0015-persistent-media-index.md), [features/library.md](features/library.md#media-index)).
- Schema version 2 with a migration that keeps the M2 trash ([database.md](database.md#migrations)).
- Native `mediaSnapshot` and `mediaDetails` replace `albumSummaries`, `mediaSizes` and `photo_manager` listing ([platform-android.md](platform-android.md#media-access)).
- **Capture dates**: resolved during the sync from the photo's metadata, then its file name, then the file date; timelines use them unless **Corrected dates** is off in Settings, at the product owner's request ([analysis-engine.md](analysis-engine.md#capture-date), [ADR 0016](decisions/0016-capture-dates-at-index-time.md)).
- **Exact duplicates**: items sharing their size are hashed (SHA-256, natively, incremental), identical hashes are grouped; a Duplicates tile at the top of every grid opens the groups of that grid, with the Best badge, pre-selected extra copies, per-group and global cleaning to the trash ([features/duplicates.md](features/duplicates.md), [ADR 0017](decisions/0017-exact-duplicates-sha256.md)).

### Verified

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test --timeout 60s` | 148 tests pass |
| Galaxy A54 (release build) | Media index confirmed by the product owner on 2026-10-26: migration of the M2 trash, instant display at launch, changes from other apps picked up on return, scroll position kept ([testing.md](testing.md#m3--media-index-to-verify-on-a-device)). Limited access and a fresh install not tested. Capture dates confirmed on 2026-10-26: received photos at their real date, camera photos unchanged, Corrected dates switch ([testing.md](testing.md#m3--capture-dates-to-verify-on-a-device)). Exact duplicates not tested yet ([testing.md](testing.md#m3--exact-duplicates-to-verify-on-a-device)). |

### Known issues

- Photos taken while the app stays in the foreground appear after pull-to-refresh or the next return to the app.

### Next steps

1. Device test of exact duplicates.
2. Bursts, in the "Certain duplicates" section.

## M2 — Actions

### Done

- System favorites from the viewer and selections ([features/favorites.md](features/favorites.md)).
- Sharing through the system share sheet, with GPS location removed from photos by default ([features/sharing.md](features/sharing.md), [ADR 0014](decisions/0014-native-sharing.md)).
- Multi-select: long press, drag to select a range with auto-scroll, selection bar with share, favorite, trash ([features/library.md](features/library.md#selection-and-actions)).
- App trash: every delete goes through it, *Undo*, Trash page with days left, restore, delete for good, daily expiry offer ([features/trash.md](features/trash.md)).
- Settings tab: theme, language, default columns, trash retention, location on share, permissions; sort of each view saved ([features/settings.md](features/settings.md)).
- First tab changed to **Camera** (camera photos only) at the product owner's request; everything else in Albums → All media.
- Video thumbnails fall back to the embedded cover or the frame at 10 %.

### Verified

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test --timeout 60s` | 101 tests pass |
| Galaxy A54 (release build) | Confirmed by the product owner: favorites, drag selection, trash and undo, delete for good, sharing, theme, language, columns, Camera tab, video thumbnails, fluidity. Details in [testing.md](testing.md#m2--to-verify-on-a-device). |

### Decisions

- **Purge at launch and resume** instead of a daily WorkManager task, accepted by the product owner ([ADR 0013](decisions/0013-trash-purge-without-background-job.md)).
- **App trash kept** rather than Android's trash ([features/trash.md](features/trash.md#known-limitations--future-work)).

### Known issues

- Whether `createFavoriteRequest` skips the confirmation with Media management is to be checked on a device.
- Video location is not removed when sharing (warned); HEIC copies lose all metadata.

### Not verified yet

- Behaviour with Media management (no system prompt for favorites and deletion), the expiry offer the next day, HEIC and video sharing, restore, sort restored after a restart, permission refresh ([testing.md](testing.md#m2--to-verify-on-a-device)).

### Next steps

1. ~~Review and merge the M2 pull request.~~ Merged (PR #3).
2. M3: persistent media index (cache) so lists show instantly at launch, then dates, exact duplicates and bursts.

## M1 — Navigation

### Done

- Photos and Videos timelines with date headers, chunked loading and pull-to-refresh ([features/library.md](features/library.md)).
- Pinch-to-zoom grid, 2–6 columns, with video durations and favorite hearts.
- Albums tab: All media, Favorites, device folders, album pages.
- Viewer: swipe, Hero transition, zoom, immersive mode; video playback with own controls ([features/viewer.md](features/viewer.md)).
- Access, limited-access, empty, error and skeleton states.
- Sorting and date filter in every timeline ([ADR 0012](decisions/0012-sort-and-date-filter.md)).
- Fast-scroll thumb with month or size bubble; grid and viewer performance work after the first device test.
- `MediaSource` on `photo_manager`, own image providers ([ADR 0009](decisions/0009-media-access.md)); `InteractiveViewer` for zoom ([ADR 0010](decisions/0010-photo-zoom.md)); `video_player` ([ADR 0011](decisions/0011-video-playback.md)).

### Verified

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test` | 68 tests pass |
| Galaxy A54 (Android 16) | Confirmed by the product owner: timelines, sorting, date filters, durations, Favorites, pinch, fast-scroll thumb, viewer swipe, and speed of Photos, Videos, Albums and the viewer. Details in [testing.md](testing.md#m1--to-verify-on-a-device). |
| Device checklist | [testing.md](testing.md#m1--to-verify-on-a-device) |

### Known issues

- New photos only appear after pull-to-refresh (automatic updates come with indexing in M3).
- The column count, sort and date filter reset at each launch. Solved in M2 for the column count and the sort; the date filter stays per session on purpose.
- Scrolling performance with very large libraries is not measured yet.

### Not verified yet

- Video progress bar fix (covered by a layout test, not re-confirmed on the phone).
- Zoom details, immersive mode, rotation, HEIC and very large photos, pull-to-refresh after a new photo, Android 14+ partial access, date filter on a folder.
- CI on GitHub for this branch (the repository is private; its status cannot be read from the development machine).

## M0 — Foundations

Merged into `main`. Summary:

- Flutter project (Android only), `minSdk 30`, `targetSdk 36`, `compileSdk 37`, strict lints, AGP 9.4.1 / Gradle 9.6.0 ([ADR 0007](decisions/0007-android-toolchain.md)).
- Architecture with tested dependency rules ([architecture.md](architecture.md)); Drift schema v1 ([database.md](database.md)).
- Own visual identity and five icon-only tabs ([design.md](design.md), [ADR 0008](decisions/0008-navigation-and-visual-identity.md)).
- Kotlin channel for "Media management" ([platform-android.md](platform-android.md)); onboarding and permissions ([features/onboarding.md](features/onboarding.md)).
- English and French; build configuration for ad IDs; CI workflow.

### Still not verified from M0

- **Permission prompts on a phone** (items 4 to 9 of the M0 checklist in [testing.md](testing.md#manual-verification-on-a-device)), including Android 14+ partial access, the most uncertain item.
- **CI result on GitHub**: the repository is private, so its status cannot be read from the development machine.
- **Release build**: `flutter build appbundle --release` has not been run locally.

## Known issues (all milestones)

- The splash screen and launcher icon are Flutter's defaults (planned for M9).
- Onboarding illustrations are Material icons (custom artwork in M9).
- Release builds are signed with the debug key (planned for M9).
- The debug APK is about 200 MB (every CPU architecture and debug symbols); Google Play delivers split release bundles.

## Open questions

- **Google Play policy for `MANAGE_MEDIA`**: to confirm before the first release ([ADR 0006](decisions/0006-permissions.md)). The app already works without it.
