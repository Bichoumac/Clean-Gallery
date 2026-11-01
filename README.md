# Clean Gallery

A photo and video gallery for Android, built with Flutter, with cleanup tools: a virtual folder of likely duplicates, a swipe-to-sort mode and a trash with a configurable retention period. **Your photos never leave your device.**

Last updated: 2026-11-01 — Milestone M7

The app is free with two small, unobtrusive ad placements, and a single "Remove ads" in-app purchase. Every feature is available to everyone.

## Status

Milestones **M0** to **M7** are merged (the map came with M6). New features are specified and waiting for answers: user albums, slideshows and memories, People (on-device face recognition). See [docs/progress.md](docs/progress.md) for details and the device checklist.

## Features

| Area | Summary | Milestone |
| --- | --- | --- |
| Onboarding | Privacy promise, media and GPS permissions, optional "Media management" | M0 ✓ |
| Navigation | Five icon-only tabs: Camera, Videos, Albums, Stats, Settings | M0 ✓ (placeholder tabs) |
| Library | Camera and video timelines with sorting and date filter, albums, zoomable grid, viewer, video playback; persistent index | M1 ✓, index M3 ✓ |
| Actions | System favorites, sharing without GPS, multi-select, trash, settings | M2 ✓ |
| Duplicates | Exact duplicates and bursts in a virtual folder; stacks in the timelines | M3 ✓, stacks M6 |
| Similar photos | Perceptual hashing, best-shot suggestion, Not duplicates, sensitivity, storage dashboard | M4 ✓ |
| Cleanup | Swipe mode, blurry photos, screenshots, large videos | M5 ✓ |
| Editing | Info panel, editor (crop, straighten, adjustments, Enhance, vignette, pencil, blur, pixelate, texts), document scanner, filters | M6 ✓ |
| Exploration | Map with clusters and mini map, search with combinable criteria (name, type, favorites, folder, area on the map, dates) | Map M6 ✓, search M7 ✓ |
| User albums | Create albums, add photos to a new or existing album | Planned |
| Slideshows and memories | Slideshows from an album or a period; automatic memories ("1 year ago") | Planned |
| People | On-device face recognition, merge two persons | Planned |
| Monetization | Banner (Albums), native card (Stats), consent, "Remove ads" purchase | Planned |

## Requirements

| Tool | Version |
| --- | --- |
| Flutter | 3.47.8 (stable) |
| JDK | 17 |
| Android SDK | Platform 37 (compile) and 36 (target), build-tools 36 |
| Gradle / AGP | 9.6.0 / 9.4.1 (downloaded by the wrapper) |
| RAM | 8 GB minimum for Gradle builds |
| Device | Android 11 (API 30) or later |

The first Android build downloads Gradle and the missing SDK packages, and takes about 25 minutes on a modest laptop.

## Setup

```sh
git clone git@github.com:Bichoumac/Clean-Gallery.git
cd Clean-Gallery
flutter pub get
dart run build_runner build   # Drift, Riverpod and freezed code
flutter gen-l10n              # English and French strings
```

Generated files (`*.g.dart`, `*.freezed.dart`, `lib/l10n/app_localizations*.dart`) are not committed. Run the two generation commands after every pull that changes annotated code or ARB files.

## Run

Connect a phone with USB debugging enabled, or start an emulator, then:

```sh
flutter run
```

Debug builds always use Google's test ad units. Release builds take production IDs from build configuration, see [lib/core/config/app_config.dart](lib/core/config/app_config.dart).

## Test and lint

```sh
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
```

See [docs/testing.md](docs/testing.md) for the test strategy.

## Build

```sh
flutter build apk --debug
flutter build appbundle --release \
  --dart-define=ADMOB_BANNER_UNIT_ID=<id> \
  --dart-define=ADMOB_NATIVE_UNIT_ID=<id> \
  -PadmobAppId=<app id>
```

Release signing is not configured yet (planned for M9).

## Documentation

- [docs/README.md](docs/README.md): index of all documentation.
- [AGENTS.md](AGENTS.md): guide for AI assistants working on this repository.
- [CHANGELOG.md](CHANGELOG.md): changes per milestone.
