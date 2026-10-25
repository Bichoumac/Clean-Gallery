# Documentation index

Every documentation file in the repository, with a one-line description. Start with [progress.md](progress.md) to see where the project stands.

Last updated: 2026-10-25 — Milestone M1

## Project

| File | Description |
| --- | --- |
| [../README.md](../README.md) | Overview, setup, build, run and test commands. |
| [../AGENTS.md](../AGENTS.md) | Entry point for AI assistants: commands, architecture map, rules. |
| [../CHANGELOG.md](../CHANGELOG.md) | Changes per milestone. |
| [progress.md](progress.md) | Milestone status, known issues, next steps. |

## Technical reference

| File | Description |
| --- | --- |
| [architecture.md](architecture.md) | Layers, module map, tabs, data flow and dependency rules. |
| [design.md](design.md) | Design system: palette, typography, shapes, navigation bar. |
| [database.md](database.md) | Drift schema, indexes and migration history. |
| [platform-android.md](platform-android.md) | Permissions and the native Kotlin channel API. |
| [testing.md](testing.md) | Test strategy, commands and fixtures. |

Planned files: `analysis-engine.md` (M3), `monetization.md` (M8), `release.md` (M9).

## Features

| File | Description |
| --- | --- |
| [features/onboarding.md](features/onboarding.md) | First-launch flow and permission requests. |
| [features/library.md](features/library.md) | Photos and Videos timelines, Albums tab, grid. |
| [features/viewer.md](features/viewer.md) | Full-screen viewer and video playback. |

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
| [0010](decisions/0010-photo-zoom.md) | Photo zoom with `InteractiveViewer` instead of `photo_view` |
| [0011](decisions/0011-video-playback.md) | Video playback with `video_player` and own controls |
