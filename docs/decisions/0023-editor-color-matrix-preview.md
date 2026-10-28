# ADR 0023 — Editor: the edit as data, colors as one matrix, saving natively

How the editor previews changes live and how they will be saved.

Last updated: 2026-10-28 — Milestone M6

- **Status**: Accepted
- **Date**: 2026-10-28

## Context

The brief asks for crop, rotate, adjustments and filters. Photos are up to 50 megapixels; the preview must follow a slider at 60 fps on the Galaxy A54, and the saved photo must look like the preview.

## Decision

- **The edit is plain data** (`PhotoEdit`, pure Dart): quarter turns, flip, a crop rectangle in fractions, adjustments from -1 to 1. Nothing is applied to pixels while editing.
- **Geometry on screen with widgets** (`RotatedBox`, `Transform.flip`, a clip), on the viewer's screen-sized preview.
- **Colors as one 4 × 5 matrix** composed in pure Dart from the adjustments (and, in part 3, the filter), shown with `ColorFilter.matrix`: a slider only repaints.
- **Saving natively** (part 3): decode the full photo, crop, rotate, flip and draw it with Android's `ColorMatrixColorFilter`, which takes the same 20 numbers, then encode JPEG and insert it with MediaStore, EXIF copied.

## Alternatives considered

- **Editing pixels in Dart with the `image` package**: exact on every platform, but decoding and encoding a 12-megapixel photo takes seconds in an isolate, so the preview could not follow a slider; and saving would hold the full photo in Dart memory.
- **Shaders** (fragment programs): curves and local adjustments would be possible, but the five adjustments and the filters are linear per pixel, which a matrix does; a shader would need a separate path to save.
- **An editing package** (image_editor, pro_image_editor…): fast to add, but its look would not fit the app's design and its saving would bypass the app's rules (trash, EXIF, indexing).

## Consequences

- The preview and the saved photo share one matrix: what is seen is what is saved, up to rounding.
- Adjustments are limited to what a color matrix can do (no curves, highlights or shadows, no sharpening).
- Part 3 needs a native method and an interface method (`PlatformBridge` or `MediaSource`) to save.
