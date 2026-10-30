# ADR 0024 — Document scanner: Otsu threshold, perspective on the canvas

How the scanner finds and flattens a page without machine learning.

Last updated: 2026-10-29 — Milestone M6

- **Status**: Accepted
- **Date**: 2026-10-29

## Context

The product owner asked for a document scanner working from an existing photo, after asking for an "Enhance" without AI: the app keeps every photo on the phone and avoids opaque models.

## Decision

- **Detection**: Otsu's threshold on a 200 px grayscale copy, the largest light area in one piece (paper is lighter than what it lies on), its four corners as the points furthest along the two diagonals. Always editable by hand; corners 8 % in when nothing is found.
- **Flattening**: a homography from the four corners to a rectangle sized by the page's longer opposite sides, applied as a perspective canvas transform, so the GPU resamples the photo once.
- **Rendering**: levels from the flattened page's histogram (color, gray, or black and white with the median paper as white).
- **Saving**: the same path as the editor (pixels rendered in Flutter, JPEG and EXIF natively).

## Alternatives considered

- **ML Kit Document Scanner** (Google Play services): better detection and its own camera UI, but a Google dependency running its own model, and its UI does not fit the app.
- **Edge detection and Hough lines** (OpenCV-like): finds pages on light tables, but heavier code or a native library (OpenCV adds tens of megabytes).
- **Adaptive thresholding** for black and white: cleaner under uneven light, but not a color matrix: it needs a pixel pass in Dart or natively.

## Consequences

- Works for a sheet on a darker surface; otherwise the user places the corners.
- Black and white is a global threshold-like stretch: strong shadows across the page may stay gray.
