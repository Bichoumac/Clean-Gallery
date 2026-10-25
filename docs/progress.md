# Progress

Status of each milestone, what is done, known issues and next steps. Update this file at the end of every milestone.

Last updated: 2026-10-25 — Milestone M2

## Milestones

| Milestone | Scope | Status |
| --- | --- | --- |
| M0 | Foundations | Merged into `main` (PR #1) |
| M1 | Navigation: timelines, albums, grid, viewer, video, sorting, date filter | Merged into `main` (PR #2) |
| M2 | Actions: favorites, sharing, multi-select, trash, basic settings | Done, awaiting device check and approval |
| M3 | Engine level 1: indexing, dates, exact duplicates, bursts | Not started |
| M4 | Engine level 2: perceptual hashes, similar photos, dashboard | Not started |
| M5 | Cleanup: Stats values, swipe mode, blurry, screenshots, large videos | Not started |
| M6 | Advanced viewer and editing | Not started |
| M7 | Exploration: map, search | Not started |
| M8 | Monetization | Not started |
| M9 | Polish and release preparation | Not started |

## M2 — Actions

### Done

- System favorites from the viewer and selections ([features/favorites.md](features/favorites.md)).
- Sharing through the system share sheet, with GPS location removed from photos by default ([features/sharing.md](features/sharing.md), [ADR 0014](decisions/0014-native-sharing.md)).
- Multi-select: long press, drag to select a range with auto-scroll, selection bar with share, favorite, trash ([features/library.md](features/library.md#selection-and-actions)).
- App trash: every delete goes through it, *Undo*, Trash page with days left, restore, delete for good, daily expiry offer ([features/trash.md](features/trash.md)).
- Settings tab: theme, language, default columns, trash retention, location on share, permissions; sort of each view saved ([features/settings.md](features/settings.md)).

### Verified

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test --timeout 60s` | 101 tests pass |
| Galaxy A54, first test (debug build) | Favorites, drag selection, emptying the trash, sharing, theme, language and columns OK. Favorites slow to show and the app generally laggy: fixed since (no list reload after actions, memoized grid, release build for testing). |

### Open question for the product owner

- **Daily WorkManager purge**: not possible as specified, since deleting other apps' media needs a request launched from a visible screen. Purge at launch and resume implemented instead; a reminder notification is an option ([ADR 0013](decisions/0013-trash-purge-without-background-job.md)).

### Known issues

- Whether `createFavoriteRequest` skips the confirmation with Media management is to be checked on a device.
- Video location is not removed when sharing (warned); HEIC copies lose all metadata.

### Next steps

1. Run the M2 device checks.
2. Decide on ADR 0013.
3. Approval of M2, then M3 (indexing, dates, exact duplicates, bursts).

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
