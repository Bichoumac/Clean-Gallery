# Changelog

All notable changes to this project are documented here, one section per milestone. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Last updated: 2026-10-25 — Milestone M0

## [Unreleased]

### Changed

- Navigation: five icon-only tabs (Photos, Videos, Albums, Stats, Settings) in a small floating bar, replacing Photos · Folders · Clean ([ADR 0008](docs/decisions/0008-navigation-and-visual-identity.md)).
- Visual identity: fixed ink/paper palette with a lime accent, bundled Manrope typeface, no shadows ([docs/design.md](docs/design.md)).
- Ad placements moved to the Albums tab (banner) and the Stats tab (native card).

### Added

- Stats tab layout: reclaimable space and the four cleanup categories (values arrive in M5).
- Navigation tests, including a 48 dp touch target check.

### Removed

- `dynamic_color` (Material You colors).

## [M0] — 2026-10-25 — Foundations

### Added

- Flutter 3.47.8 project for Android only, `minSdk 30`, `targetSdk 36`, `compileSdk 37`.
- Android toolchain AGP 9.4.1 and Gradle 9.6.0 (template: 9.1.0 and 9.3.1), required by `permission_handler` 13 ([ADR 0007](docs/decisions/0007-android-toolchain.md)).
- Gradle heap limited to 3 GB so builds fit on 8 GB machines.
- Manual device verification checklist in [docs/testing.md](docs/testing.md#manual-verification-on-a-device).
- Strict lints with `very_good_analysis`.
- Layered architecture: `analysis`, `domain`, `core`, `platform`, `features`.
- Material 3 theme with dynamic colors (Material You) and dark mode.
- go_router navigation with an onboarding redirect and a three-tab shell (placeholder tabs).
- Drift database, schema version 1, with all tables from the specification and a migration strategy.
- Kotlin MethodChannel `clean_gallery/platform`: "Media management" status, settings shortcut, SDK version.
- Platform interfaces `PlatformBridge` and `PermissionService` with Android implementations.
- Onboarding: privacy promise, media access (including Android 14+ partial access), GPS metadata access, optional "Media management".
- English and French localization.
- Build configuration: Google test ad IDs in debug; production IDs from `--dart-define` and the `admobAppId` Gradle property.
- Tests: database, settings, onboarding controller, onboarding screen, architecture rules.
- GitHub Actions CI: formatting, analysis, tests, APK and AAB builds, Markdown lint and link check.
- Documentation skeleton and ADRs 0001 to 0007.

### Not verified

- The app has not been checked on a real screen yet; see [docs/progress.md](docs/progress.md#not-verified-yet).
