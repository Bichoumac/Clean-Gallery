# ADR 0002 — Layered architecture with platform interfaces

How the code is split into layers, and why a `domain/` folder was added to the structure from the brief.

Last updated: 2026-10-25 — Milestone M0

- **Status**: Accepted
- **Date**: 2026-10-25

## Context

The app targets Android first, but iOS must be addable later without touching the UI or the analysis engine. The analysis engine must be pure Dart, independent from Flutter, unit-testable and runnable in an isolate. The brief proposes `lib/core`, `lib/analysis`, `lib/platform` and `lib/features`.

## Decision

1. **Platform interfaces**: every platform capability is an interface in `lib/platform/` (`PlatformBridge`, `PermissionService`, later `MediaSource`, `AdsService`, `PurchaseService`). Android implementations live in `lib/platform/android/`. Only [lib/core/providers.dart](../../lib/core/providers.dart) picks the implementation.
2. **Domain folder**: shared entities and enums go in `lib/domain/`, outside `core/`. The engine needs types such as `MediaKind` and `DuplicateKind`, but must not import `core/`, which depends on Flutter and Drift.
3. **Rules enforced by tests**: [dependency_rules_test.dart](../../test/architecture/dependency_rules_test.dart) fails if `analysis/` or `domain/` import Flutter or another app layer, or if a feature imports `platform/android/`.

## Alternatives considered

- **Domain types inside `analysis/`**: the database and UI would then import the engine for simple enums, which blurs its boundary.
- **A separate Dart package for the engine** (`packages/analysis/`): strongest isolation, but adds a second `pubspec.yaml` and path dependency. The import test gives the same guarantee for less setup. Revisit if the engine grows its own dependencies.

## Consequences

- Adding iOS is a matter of new classes in `lib/platform/ios/` and one switch in the providers.
- Every new service needs an interface and a fake, which costs a little more code but keeps tests fast and device-free.

See [architecture.md](../architecture.md) for the full layer map.
