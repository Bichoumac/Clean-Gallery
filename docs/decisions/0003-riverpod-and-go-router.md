# ADR 0003 — Riverpod with code generation, and go_router

How state and navigation are handled, and how the router decides between onboarding and the main tabs.

Last updated: 2026-10-25 — Milestone M0

- **Status**: Accepted
- **Date**: 2026-10-25

## Context

The brief recommends `flutter_riverpod` (with `riverpod_generator` where relevant) and `go_router`. The first screen depends on a value stored in the database (onboarding done or not), and services must be replaceable in tests.

## Decision

- **Riverpod 3 with `@riverpod` code generation** for every provider. Services are providers returning interfaces; tests override them.
- **Controllers as `Notifier`s** holding a `freezed` state. Screens render the state and forward user actions; they never call services directly.
- **go_router with a `StatefulShellRoute`** for the three tabs, so each tab keeps its own navigation stack.
- **Onboarding redirect without a loading screen**: `main()` reads the flag before `runApp` and passes it as a provider override. The router is created once; its redirect reads the current flag, and a `refreshListenable` re-runs it when onboarding completes.

## Alternatives considered

- **Async provider for the flag, with a splash screen**: one more state to design and test, for a read that takes milliseconds.
- **Rebuilding the router when the flag changes**: loses navigation state and recreates every route.
- **Navigating with `context.go` after completion**: works, but spreads redirect rules between the router and screens.

## Consequences

- Any state the router depends on must notify `refreshListenable`; otherwise the redirect is not re-run. The widget test "skip goes straight to the main shell" caught exactly this during M0.
- Code generation is required after editing providers: `dart run build_runner build`.
