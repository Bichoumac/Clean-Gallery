# ADR 0031 — Page transitions of our own

How the app moves between tabs and pages, and why it does not use Flutter's or Material's ready-made transitions.

Last updated: 2026-11-08 — Page transitions

- **Status**: Accepted
- **Date**: 2026-11-08

## Context

The product owner asked for modern, smooth transitions everywhere (2026-11-08): a zoom when a photo opens, a slide between tabs. Tabs changed at once; pages used Flutter's default Android transition, a quick fade-and-slide that read as an instant change on the phone. The photo's flight to the viewer ended on a full-screen box, so the square thumbnail jumped to the whole photo at the end.

## Decision

- **One page transition for every Material page**, `AppPageTransitionsBuilder`, set in the theme's `pageTransitionsTheme`, so go_router routes need no change: the page slides in from the right over the previous one, which recedes to 94 % and darkens.
- **Tile to page**: a tile calls `TransitionOrigin.mark(context)` before it navigates; the next page to open takes the mark and grows out of the tile instead of sliding. The mark lasts 600 ms and is taken once, so a tap that opens no page does not leak into a later one. No route or `extra` carries it.
- **Predictive back** is handled by the same builder, as Flutter's `PredictiveBackPageTransitionsBuilder` does, but only by a page whose tickers are on: a page in a hidden tab or under another page never takes the gesture.
- **Tabs**: `TabSwitcher` replaces the `IndexedStack` of the shell; both tabs slide together like a carousel. Every tab keeps the same widgets around it at all times, so none loses its state.
- **Viewer**: the photo's hero flies to the photo's own frame inside the viewer (`mediaHeroRectTween`), with the `spring` token.
- Durations and curves are tokens of `AppMotion`; under reduced motion every transition is instant.

## Alternatives considered

- **The `animations` package (`OpenContainer`, shared axis)**: `OpenContainer` pushes its own route, outside go_router's locations, and would need a wrapper on every tile. A dependency for two effects.
- **Material's `FadeForwardsPageTransitionsBuilder`**: the platform default, judged too discreet by the product owner.
- **Swiping between tabs**: conflicts with the pinch that changes grid columns and with drag selection.

## Consequences

- Pages opened with `CustomTransitionPage` (viewer, slideshow) keep their fade and do not make the page below recede.
- A page's state survives its transition only because the widget tree around it never changes shape; new effects must keep that rule.
- Widget tests that pump a fixed duration after a navigation may need `pumpAndSettle`.
