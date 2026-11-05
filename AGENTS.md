# AGENTS.md

Entry point for AI assistants working on Clean Gallery. Read this first, then follow the links to `docs/` for depth.

Last updated: 2026-11-05 — Milestone M11

## Project summary

- Android photo and video gallery written in Flutter, with cleanup tools (duplicates, swipe sorting, trash).
- Everything runs on device: no media or metadata ever leaves the phone.
- Free with two light ad placements; one non-consumable "Remove ads" purchase.
- Android only for now; all platform code sits behind interfaces so iOS can be added later.
- Built milestone by milestone (M0 to M12); the current state is in [docs/progress.md](docs/progress.md).

## Essential commands

```sh
flutter pub get                      # install dependencies
dart run build_runner build          # generate Drift, Riverpod and freezed code
flutter gen-l10n                     # generate localizations from lib/l10n/*.arb
flutter run                          # run on a connected device
flutter test                         # all tests
flutter analyze                      # lints (very_good_analysis)
dart format lib test                 # format
flutter build apk --debug            # debug APK
flutter build appbundle --release    # release bundle
```

Flutter is installed in `~/sdk/flutter` on the development machine; add `~/sdk/flutter/bin` to `PATH` if `flutter` is not found.

Generated files are not committed. After editing a class annotated with `@DriftDatabase`, `@riverpod` or `@freezed`, rerun `build_runner`.

## Architecture map

| Folder | Contains | Add new code here when… |
| --- | --- | --- |
| `lib/analysis/` | Detection engine, pure Dart | adding an algorithm (dates, hashes, grouping). No Flutter imports. |
| `lib/domain/` | Entities and enums shared by all layers | adding a business concept. No Flutter imports. |
| `lib/core/` | Theme, database, router, providers, config | adding app-wide infrastructure. |
| `lib/core/brand/` | The mark and gauge, glass bars, mosaic tiles, empty state, *Best* pill | adding something that carries the identity. |
| `lib/core/media/` | `MediaIndex` (syncs the `assets` table with the device), `DuplicateScan` (certain duplicates, perceptual hashes, similar groups), media list providers reading it, the duplicates tile, thumbnail widget, formatting, `MediaActions`, selection bar | adding media code shared by several features. |
| `lib/core/settings/` | `AppSettings` and its controller | adding a user setting (also add a key in `SettingKeys`). |
| `lib/platform/` | Interfaces (`MediaSource`, `PlatformBridge`, `PermissionService`, `MusicPlayer`, `ReminderService`, `AdsService`, `PurchaseService`, …) | adding a platform capability: interface here, implementation in `platform/android/`. |
| `lib/platform/android/` | Android implementations | implementing an interface for Android. |
| `lib/features/<feature>/` | Screens, controllers, feature logic | building a user-facing feature. |
| `lib/l10n/` | ARB files (`app_en.arb`, `app_fr.arb`) | adding any user-visible string. |
| `android/app/src/main/kotlin/` | Native Kotlin channel (`MainActivity.kt`) | needing an Android API no package covers. |
| `test/` | Mirrors `lib/`; fakes in `test/helpers/` | testing anything. |

Full details and diagrams: [docs/architecture.md](docs/architecture.md).

## Coding conventions

- **Naming**: files `snake_case.dart`; one public widget or class per file when practical; route paths in `AppRoutes`, setting keys in `SettingKeys`.
- **State**: Riverpod with code generation (`@riverpod`). Screens render state and forward actions to a controller (`Notifier`); controllers depend on interfaces read through providers, never on concrete Android classes.
- **Immutability**: state and entity classes use `freezed`.
- **Database**: Drift tables in [lib/core/database/tables.dart](lib/core/database/tables.dart). Any schema change bumps `schemaVersion` and adds a migration step, see [docs/database.md](docs/database.md).
- **Errors**: platform calls can throw `PlatformException`; catch them in the controller and expose a user-facing state, never crash the UI.
- **Tests**: app-level widget tests use `pumpTestApp` inside `testApp` (not `testWidgets`), so Drift streams are closed; run with `flutter test --timeout 60s`. Work sent to an isolate goes through `analysisRunnerProvider`, which `pumpTestApp` runs inline.
- **Localization**: no hard-coded user-visible strings. Add each string to both `app_en.arb` and `app_fr.arb`.
- **Design**: colors from `Theme.of(context).colorScheme` only, one accent, no shadows, neutral background behind photo grids, tab pages built on `TabPage`. See [docs/design.md](docs/design.md).
- **Docs**: public Dart APIs get `///` comments; Kotlin channel methods get KDoc.

## Non-negotiable rules

1. Never use `MANAGE_EXTERNAL_STORAGE`. A test enforces it.
2. Every delete in the app goes through the app trash first (`MediaActions.trash`); only the trash deletes for good (`MediaActions.deleteForever`).
3. Ads appear only in the three allowed placements: a banner at the bottom of the Albums tab, one native card in the Stats tab ([ADR 0008](docs/decisions/0008-navigation-and-visual-identity.md)), and one interstitial before a manual slideshow, at most every 5 minutes (product owner, 2026-11-05, [ADR 0030](docs/decisions/0030-ads-and-purchase.md)). No other interstitial, and no rewarded or app-open ads (a test enforces it).
4. No media data or metadata is ever sent to any SDK, ads included.
5. Platform code lives only behind interfaces in `lib/platform/`. Features never import `platform/android/` (a test enforces it).
6. `lib/analysis/` and `lib/domain/` never import Flutter (a test enforces it).
7. No production IDs or secrets in the source. Use `--dart-define` and Gradle properties.
8. Update the documentation in the same commit as the code change. A milestone is not done until `docs/progress.md`, `CHANGELOG.md` and the affected feature docs are updated.
9. Significant technical choices get an ADR in `docs/decisions/`.
10. Face recognition (People) runs on the phone only: models bundled in the app, never downloaded, no cloud API or ML Kit, no network call from the face code (a test enforces it).
11. User albums and saved slideshows never move, copy or delete a file: they are lists in the database.
12. No background work that reads media or the database: memories and rituals only schedule notifications; the app builds the slideshow when it is opened. `ReminderReceiver` reads only its list of notifications (a test enforces it, [ADR 0027](docs/decisions/0027-notifications-without-background-work.md)).

## Where to read more

- [docs/working-notes.md](docs/working-notes.md): **read first** — where to pick up, how to work with the product owner, privacy during device tests, development machine notes.
- [docs/README.md](docs/README.md): documentation index.
- [docs/progress.md](docs/progress.md): what is done and what is next.
- [docs/architecture.md](docs/architecture.md): layers and dependency rules.
- [docs/design.md](docs/design.md): palette, typography, logo, motion.
- [docs/visual-refresh.md](docs/visual-refresh.md): brief and mockups of the identity, and the choices made while building it.
- [docs/monetization.md](docs/monetization.md): ads, consent, purchase and outside setup.
- [docs/database.md](docs/database.md): schema and migrations.
- [docs/platform-android.md](docs/platform-android.md): permissions and native channel API.
- [docs/testing.md](docs/testing.md): test strategy.
- [docs/decisions/](docs/decisions/): architecture decision records.
