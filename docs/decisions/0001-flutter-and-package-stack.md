# ADR 0001 — Flutter version and package stack

The Flutter version and the packages used in M0, why each was chosen, and where the stack deviates from the brief.

Last updated: 2026-10-25 — Milestone M0

- **Status**: Accepted
- **Date**: 2026-10-25

## Context

The brief requires the latest stable Flutter and asks to check, before adding any package, that it is actively maintained and compatible with that Flutter version. It recommends a stack, and asks to explain any replacement.

## Decision

Flutter **3.47.8** (stable, released 2026-10-22), pinned in CI.

Packages added in M0, with the latest publish date checked on pub.dev on 2026-10-25:

| Package | Version | Last published | Role | In brief |
| --- | --- | --- | --- | --- |
| `flutter_riverpod` | 3.4.3 | 2026-09-03 | State management | Yes |
| `riverpod_annotation` / `riverpod_generator` | 4.0.7 / 4.0.9 | 2026-09-03 | Provider code generation | Yes |
| `go_router` | 18.1.1 | 2026-10-20 | Navigation | Yes |
| `drift` / `drift_flutter` / `drift_dev` | 2.35.3 / 0.3.1 / 2.35.2 | 2026-10-23 | SQLite database | Yes |
| `freezed` / `freezed_annotation` | 4.0.3 / 3.1.0 | 2026-10-17 | Immutable classes | Yes |
| `intl`, `flutter_localizations` | 0.20.3 / SDK | 2026-06-25 | Localization | Yes (ARB) |
| `dynamic_color` | **1.9.0** | 2026-08-07 | Material You colors | No (needed for "dynamic colors") |
| `permission_handler` | 13.0.2 | 2026-09-04 | Runtime permissions | No |
| `very_good_analysis` | 11.0.0 | 2026-09-03 | Lints | Yes (one of two options) |
| `mocktail` | 1.0.5 | 2026-04-10 | Test mocks | No |
| `build_runner` | 2.17.x | 2026-10-14 | Code generation | Implied |

Packages for later milestones (`photo_manager`, `media_kit`, `flutter_map`, `google_mobile_ads`, `in_app_purchase`, …) are checked when the milestone that needs them starts, and recorded in a new ADR if they deviate from the brief.

## Deviations from the brief

### `dynamic_color` stays on 1.x

`dynamic_color` 2.x returns color schemes from the separate `material_ui` package, whose `ColorScheme` type is not the one Flutter's `ThemeData` accepts: the project failed to compile with it. Version 1.9.0 returns Flutter's own `ColorScheme`, is recent (August 2026) and does the same job. Revisit when Flutter's Material library and `material_ui` converge.

### `permission_handler` for runtime permissions

The brief lists a Kotlin module "for anything packages don't cover". Runtime permissions are covered well by `permission_handler`, which maps `photos` and `videos` to the right Android permission per version. Only the "Media management" special access, which no package exposes, goes through the native channel. See [ADR 0006](0006-permissions.md).

`permission_handler` 13 requires `compileSdk 37`, which forced a newer Android toolchain than the Flutter template: see [ADR 0007](0007-android-toolchain.md).

### `mocktail` for tests

Not mentioned in the brief. It needs no code generation, which keeps tests simple. Hand-written fakes are preferred for interfaces used in many tests.

## Consequences

- Upgrading Flutter means updating `FLUTTER_VERSION` in [ci.yml](../../.github/workflows/ci.yml) and this ADR.
- `flutter pub outdated` lists packages held back by constraints; review it at the start of each milestone.
