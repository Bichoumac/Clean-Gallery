# ADR 0010 — Photo zoom with `InteractiveViewer` instead of `photo_view`

Why the viewer zooms with a Flutter built-in widget rather than the package suggested in the brief.

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

Use Flutter's **`InteractiveViewer`** ([zoomable_image.dart](../../lib/features/viewer/zoomable_image.dart)), maintained with the framework:

- pinch-to-zoom up to 5×, with panning;
- double-tap zoom to 2.5× around the tapped point, and back to fit, animated with a `Matrix4Tween`;
- the viewer disables page swiping while a photo is zoomed, detected from the transformation's scale.

## Alternatives considered

- **`photo_view`**: offers the same gallery features out of the box, but an unmaintained package in the most-used screen is a risk with each Flutter upgrade.

## Consequences

- About 100 lines of our own code to maintain and test.
- Gestures must be checked on a device (listed in [testing.md](../testing.md#m1--to-verify-on-a-device)).
