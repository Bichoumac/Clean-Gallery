# Architecture

Clean Gallery uses a layered architecture organized by feature. Platform-specific code sits behind interfaces, so the UI and the analysis engine never depend on Android directly. This file describes the layers, where code lives, how data flows and which dependencies are allowed.

Last updated: 2026-10-25 — Milestone M0

## Layers

```mermaid
flowchart TD
    subgraph Presentation
        F[features/*<br/>screens, controllers]
        R[core/router]
    end
    subgraph Domain
        D[domain/<br/>entities, enums]
    end
    subgraph Data
        DB[core/database<br/>Drift]
        P[platform/<br/>interfaces]
        PA[platform/android/<br/>implementations]
    end
    A[analysis/<br/>pure Dart engine]
    K[Kotlin MainActivity<br/>MethodChannel]

    F --> D
    F --> P
    F --> DB
    F --> A
    R --> F
    DB --> D
    A --> D
    PA -. implements .-> P
    PA --> K
```

| Layer | Folder | Role |
| --- | --- | --- |
| Presentation | `lib/features/`, `lib/core/router/`, `lib/core/theme/` | Material 3 widgets, Riverpod controllers, routes. |
| Domain | `lib/domain/` | Entities and enums shared by every layer. |
| Data | `lib/core/database/`, `lib/platform/` | Drift database, platform interfaces and their Android implementations. |
| Analysis engine | `lib/analysis/` | Detection algorithms, pure Dart, run in an isolate (from M3). |

The brief lists `core/`, `analysis/`, `platform/` and `features/` under `lib/`. `lib/domain/` is added so that the engine and the database share types without the engine depending on `core/` (see [ADR 0002](decisions/0002-layered-architecture.md)).

## Module map

| Path | Contents |
| --- | --- |
| [lib/main.dart](../lib/main.dart) | Opens the database, reads the onboarding flag, starts the app. |
| [lib/app.dart](../lib/app.dart) | Root widget: theme, localization, router. |
| [lib/core/providers.dart](../lib/core/providers.dart) | App-wide providers: database, settings, platform services. |
| [lib/core/config/app_config.dart](../lib/core/config/app_config.dart) | Build-time configuration (ad unit IDs). |
| [lib/core/database/](../lib/core/database/) | Tables, database class, settings repository. See [database.md](database.md). |
| [lib/core/router/](../lib/core/router/) | Routes, redirect rules, three-tab shell. |
| [lib/core/theme/app_theme.dart](../lib/core/theme/app_theme.dart) | Material 3 theme. |
| [lib/domain/enums.dart](../lib/domain/enums.dart) | `MediaKind`, `DateSource`, `DuplicateKind`, `SwipeAction`. |
| [lib/analysis/](../lib/analysis/) | Analysis engine; currently only `analysisVersion`. |
| [lib/platform/](../lib/platform/) | `PlatformBridge`, `PermissionService` interfaces. |
| [lib/platform/android/](../lib/platform/android/) | Android implementations. See [platform-android.md](platform-android.md). |
| [lib/features/onboarding/](../lib/features/onboarding/) | Onboarding. See [features/onboarding.md](features/onboarding.md). |
| [lib/l10n/](../lib/l10n/) | ARB files for English and French. |

## Dependency rules

1. `analysis/` and `domain/` import neither Flutter nor any other app layer. They stay testable with plain Dart and can run in an isolate.
2. `features/` depend on interfaces in `platform/`, never on `platform/android/`. Concrete implementations are wired only in [lib/core/providers.dart](../lib/core/providers.dart).
3. Only `platform/android/` talks to the Kotlin MethodChannel.
4. Features do not import each other's internals. Shared code moves to `core/` or `domain/`.

Rules 1 and 2 are checked by [test/architecture/dependency_rules_test.dart](../test/architecture/dependency_rules_test.dart).

## Dependency injection

Every service is a Riverpod provider returning an interface. Tests and a future iOS build override the provider:

```dart
ProviderScope(
  overrides: [
    permissionServiceProvider.overrideWithValue(FakePermissionService()),
  ],
  child: const CleanGalleryApp(),
)
```

## Startup flow

```mermaid
sequenceDiagram
    participant M as main()
    participant DB as AppDatabase
    participant R as GoRouter
    M->>DB: open (background isolate)
    M->>DB: read onboarding_completed
    M->>R: runApp with initial flag
    alt onboarding not completed
        R->>R: redirect to /onboarding
    else completed
        R->>R: show /photos
    end
```

The flag is read before the first frame, so the router chooses the first screen synchronously, without a loading state. When onboarding completes, the router's `refreshListenable` re-runs the redirect.

## Adding an iOS implementation later

1. Implement each interface in `lib/platform/` under a new `lib/platform/ios/` folder.
2. Pick the implementation per platform in [lib/core/providers.dart](../lib/core/providers.dart).
3. No change is needed in `features/`, `analysis/` or `domain/`.
