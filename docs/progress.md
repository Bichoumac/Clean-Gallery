# Progress

Status of each milestone, what is done, known issues and next steps. Update this file at the end of every milestone.

Last updated: 2026-10-25 — Milestone M0

## Milestones

| Milestone | Scope | Status |
| --- | --- | --- |
| M0 | Foundations | Done, awaiting device check and approval |
| M1 | Navigation: folders, grid, timeline, viewer, video | Not started |
| M2 | Actions: favorites, sharing, multi-select, trash, basic settings | Not started |
| M3 | Engine level 1: indexing, dates, exact duplicates, bursts | Not started |
| M4 | Engine level 2: perceptual hashes, similar photos, dashboard | Not started |
| M5 | Cleanup: Clean tab, swipe mode, blurry, screenshots, large videos | Not started |
| M6 | Advanced viewer and editing | Not started |
| M7 | Exploration: map, search | Not started |
| M8 | Monetization | Not started |
| M9 | Polish and release preparation | Not started |

## M0 — Foundations

### Done

- Flutter project (Android only), `minSdk 30`, `targetSdk 36`, `compileSdk 37`, strict lints.
- Folder structure from [architecture.md](architecture.md), with dependency rules enforced by tests.
- Own visual identity: ink/paper palette, lime accent, Manrope, light and dark ([design.md](design.md)).
- Router with onboarding redirect and five icon-only tabs in a floating bar: Photos, Videos, Albums, Stats, Settings ([ADR 0008](decisions/0008-navigation-and-visual-identity.md)). Stats has its final layout with "—" values; the other tabs are placeholders.
- Drift database, schema v1, all tables, migration strategy ([database.md](database.md)).
- Kotlin channel for "Media management" ([platform-android.md](platform-android.md)).
- Onboarding with media, GPS and "Media management" permissions ([features/onboarding.md](features/onboarding.md)).
- English and French strings.
- Build configuration for ad IDs (test IDs in debug).
- Android toolchain upgraded to AGP 9.4.1 and Gradle 9.6.0, required by `permission_handler` ([ADR 0007](decisions/0007-android-toolchain.md)).
- CI workflow written.

### Verified

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `dart format --set-exit-if-changed lib test` | Clean |
| `flutter test` | 25 tests pass |
| `flutter build apk --debug` | Builds (first build about 25 minutes, later builds a few minutes) |
| Android 14 emulator | APK installs and starts; onboarding screen is built (seen in the widget tree, not on screen) |
| Galaxy A54, Android 16 | First design: starts, French strings, tabs, onboarding flag persists. Permissions and new design not checked yet. |

### Not verified yet

- **Permission prompts and the new design have not been checked on a phone.** The full list of device checks is in [testing.md](testing.md#manual-verification-on-a-device).
- **Android 14+ partial access**: relies on `permission_handler` reporting `limited`; the most uncertain item of the list.
- **CI**: the workflow has not run yet; it runs on the first push to GitHub. The release AAB job and the docs lint have never run.
- **Release build**: `flutter build appbundle --release` has not been run locally.

### Known issues

- The splash screen and launcher icon are Flutter's defaults (planned for M9).
- Onboarding illustrations are Material icons in tinted circles (custom artwork in M9).
- Release builds are signed with the debug key (planned for M9).
- The debug APK is 180 MB, because it contains every CPU architecture and debug symbols. Release bundles are split per device by Google Play.

### Open questions for later milestones

- **Google Play policy for `MANAGE_MEDIA`**: to confirm before the first release ([ADR 0006](decisions/0006-permissions.md)). The app already works without it.

### Next steps

1. Run the M0 device checks on a phone ([testing.md](testing.md#manual-verification-on-a-device)).
2. Check that CI passes on GitHub.
3. Approval of M0, then M1 (navigation and viewer).
