# Clean Gallery

A photo and video gallery for Android, built with Flutter, with cleanup tools: a virtual folder of likely duplicates, a swipe-to-sort mode and a trash with a configurable retention period. **Your photos never leave your device.**

Last updated: 2026-11-08 — Open source

The app is free software under the [GNU GPL v3](LICENSE): no ads, no in-app purchase, no tracking. Its [privacy policy](PRIVACY.md) fits on one page.

## Status

Milestones **M0** to **M9**, the [visual refresh](docs/visual-refresh.md) and the page transitions are merged; the ads of M11 were removed when the app went open source. People, with on-device face recognition (M10), is postponed. **M12**, the preparation of the first release (1.0.0), is in progress. See [docs/progress.md](docs/progress.md) for details and the device checklist.

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
| User albums | Create albums, add photos to a new or existing album; no file is moved | M8 ✓ |
| Slideshows and memories | Slideshows from an album, a selection or a period, with music; saved slideshows; automatic memories ("1 year ago"); rituals with a notification, no background work | M9 ✓ |
| Visual refresh | Warm Éclat Soleil identity, logo and app icon, mosaics, motion, page transitions | ✓ |
| About and release | About page, privacy policy link, release signing, store texts | M12 |
| People | On-device face recognition, merge two persons | Postponed |

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
flutter build apk --release --split-per-abi   # one APK per architecture
flutter build appbundle --release
```

Release builds are signed with the key named in `android/key.properties`, which is never committed; without it they fall back to the debug key, fine for trying a release build. Creating the key, the release checklist and the publishing channels: [docs/release.md](docs/release.md).

## Documentation

- [docs/README.md](docs/README.md): index of all documentation.
- [AGENTS.md](AGENTS.md): guide for AI assistants working on this repository.
- [CHANGELOG.md](CHANGELOG.md): changes per milestone.

## License

Clean Gallery is free software: you can redistribute it and modify it under the terms of the [GNU General Public License, version 3](LICENSE), as published by the Free Software Foundation. It comes with no warranty. Fonts in `assets/fonts/` keep their own license (SIL Open Font License, next to each font).
