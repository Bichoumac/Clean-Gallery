# Documentation index

Every documentation file in the repository, with a one-line description. Start with [progress.md](progress.md) to see where the project stands.

Last updated: 2026-10-29 — Milestone M6

## Project

| File | Description |
| --- | --- |
| [../README.md](../README.md) | Overview, setup, build, run and test commands. |
| [../AGENTS.md](../AGENTS.md) | Entry point for AI assistants: commands, architecture map, rules. |
| [../CHANGELOG.md](../CHANGELOG.md) | Changes per milestone. |
| [progress.md](progress.md) | Milestone status, known issues, next steps. |
| [working-notes.md](working-notes.md) | Where to pick up, working agreements with the product owner, development machine notes. |

## Technical reference

| File | Description |
| --- | --- |
| [architecture.md](architecture.md) | Layers, module map, tabs, data flow and dependency rules. |
| [design.md](design.md) | Design system: palette, typography, shapes, navigation bar. |
| [database.md](database.md) | Drift schema, indexes and migration history. |
| [platform-android.md](platform-android.md) | Permissions and the native Kotlin channel API. |
| [analysis-engine.md](analysis-engine.md) | Analysis algorithms (capture dates, exact duplicates, bursts, similar photos, best pick), thresholds, rationale and performance. |
| [testing.md](testing.md) | Test strategy, commands and fixtures. |

Planned files: `monetization.md` (M8), `release.md` (M9).

## Features

| File | Description |
| --- | --- |
| [features/onboarding.md](features/onboarding.md) | First-launch flow and permission requests. |
| [features/library.md](features/library.md) | Photos and Videos timelines, Albums tab, grid. |
| [features/viewer.md](features/viewer.md) | Full-screen viewer and video playback. |
| [features/favorites.md](features/favorites.md) | System favorites. |
| [features/sharing.md](features/sharing.md) | Share sheet and location removal. |
| [features/trash.md](features/trash.md) | App trash, retention and purge. |
| [features/settings.md](features/settings.md) | Settings tab. |
| [features/duplicates.md](features/duplicates.md) | Duplicates tile and screen: certain and similar groups, Best badge, Not duplicates, cleaning. |
| [features/stats.md](features/stats.md) | Stats tab: storage dashboard. |
| [features/cleanup.md](features/cleanup.md) | Cleanup lists: old screenshots, large videos, blurry photos. |
| [features/swipe.md](features/swipe.md) | Sort mode: swipe left to trash, right to keep, undo, resumable sessions. |
| [features/map.md](features/map.md) | Map of located photos, clusters, area grid, info panel mini map. |
| [features/editor.md](features/editor.md) | Photo editor: crop, straighten, adjustments, Enhance, vignette, pencil, blur, pixelate, texts, saving. |
| [features/scan.md](features/scan.md) | Document scanner: page corners, perspective, color / gray / black and white. |

One file per feature is added as each feature is built.

## Decisions

| ADR | Decision |
| --- | --- |
| [0001](decisions/0001-flutter-and-package-stack.md) | Flutter version and package stack |
| [0002](decisions/0002-layered-architecture.md) | Layered architecture with platform interfaces |
| [0003](decisions/0003-riverpod-and-go-router.md) | Riverpod with code generation, and go_router |
| [0004](decisions/0004-drift-database.md) | Drift on a background isolate |
| [0005](decisions/0005-lints.md) | `very_good_analysis` lints and exceptions |
| [0006](decisions/0006-permissions.md) | Permission handling and `minSdk 30` |
| [0007](decisions/0007-android-toolchain.md) | Android toolchain: AGP 9.4.1, Gradle 9.6.0, `compileSdk 37` |
| [0008](decisions/0008-navigation-and-visual-identity.md) | Five-tab navigation and own visual identity |
| [0009](decisions/0009-media-access.md) | Media access with `photo_manager` and own image providers |
| [0010](decisions/0010-photo-zoom.md) | Own photo zoom instead of `photo_view` or `InteractiveViewer` |
| [0011](decisions/0011-video-playback.md) | Video playback with `video_player` and own controls |
| [0012](decisions/0012-sort-and-date-filter.md) | Sorting and date filter in every timeline |
| [0013](decisions/0013-trash-purge-without-background-job.md) | Trash purge at launch and resume, without a background job |
| [0014](decisions/0014-native-sharing.md) | Sharing with native intents instead of `share_plus` |
| [0015](decisions/0015-persistent-media-index.md) | Persistent media index in Drift |
| [0016](decisions/0016-capture-dates-at-index-time.md) | Capture dates resolved at index time, without reading files |
| [0017](decisions/0017-exact-duplicates-sha256.md) | Exact duplicates with SHA-256 on size collisions |
| [0018](decisions/0018-perceptual-hashes-from-thumbnails.md) | Perceptual hashes from grayscale thumbnails, computed in Dart |
| [0019](decisions/0019-similar-photo-search.md) | Similar photo search with multi-index hashing instead of a BK-tree |
| [0020](decisions/0020-blur-and-brightness-with-the-hashes.md) | Blur and brightness measured with the hashes, on 256-pixel thumbnails |
| [0021](decisions/0021-hazy-photos-are-not-blurry.md) | Hazy photos are not blurry: sharpness relative to contrast |
| [0022](decisions/0022-map-tiles-and-grid-clusters.md) | Map: OpenStreetMap tiles with flutter_map, clusters on a grid |
| [0023](decisions/0023-editor-color-matrix-preview.md) | Editor: the edit as data, one paint function for preview and saving |
| [0024](decisions/0024-document-scanner.md) | Document scanner: Otsu threshold, perspective on the canvas |
