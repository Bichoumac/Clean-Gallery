# ADR 0010 — Own photo zoom instead of `photo_view` or `InteractiveViewer`

Why the viewer zooms with its own gesture handling rather than the package suggested in the brief or Flutter's built-in widget.

Last updated: 2026-10-25 — Milestone M1

- **Status**: Accepted
- **Date**: 2026-10-25

## Context

The brief suggests `photo_view` for the viewer and zoom, and asks to check that each package is actively maintained.

| Package | Version | Last published |
| --- | --- | --- |
| `photo_view` | 0.15.0 | 2024-04-17 |

`photo_view` has had no release for two and a half years.

## Decision

Own zoom in [zoomable_image.dart](../../lib/features/viewer/zoomable_image.dart):

- a `ScaleGestureRecognizer` subclass that **only claims one-finger drags while the photo is zoomed**; at fit scale, one finger belongs to the page view (swipe to the next photo) and two fingers zoom;
- pinch-to-zoom up to 5× around the fingers, panning clamped to the screen, springing back below 1×;
- double-tap zoom to 2.5× around the tapped point, and back to fit, animated with a `Matrix4Tween`;
- the viewer locks page swiping while a photo is zoomed.

### History

The first M1 version used Flutter's `InteractiveViewer`. On the phone, swiping between photos did not work. `InteractiveViewer` was suspected first (its scale recognizer also accepts one-finger pans) and replaced by the own recognizer; the tests still failed, and the actual cause was the viewer's top bar covering the whole screen (fixed in [viewer_screen.dart](../../lib/features/viewer/viewer_screen.dart)). Whether `InteractiveViewer` would also have blocked swipes was not tested. The own zoom is kept because it makes the rule explicit (one finger swipes, two fingers zoom) and lets the viewer load the full-resolution image only when zooming.

## Alternatives considered

- **`photo_view`**: offers the same gallery features out of the box, but an unmaintained package in the most-used screen is a risk with each Flutter upgrade.
- **`InteractiveViewer`**: maintained with Flutter, but its gestures cannot be restricted to two fingers at fit scale.

## Consequences

- About 150 lines of our own code, covered by widget tests (swipe, pinch, pan while zoomed, double-tap back).
- Gestures must be checked on a device (listed in [testing.md](../testing.md#m1--to-verify-on-a-device)).
