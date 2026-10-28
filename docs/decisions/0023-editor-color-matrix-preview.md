# ADR 0023 — Editor: the edit as data, colors as one matrix, saving natively

How the editor previews changes live and how they will be saved.

Last updated: 2026-10-29 — Milestone M6

- **Status**: Accepted
- **Date**: 2026-10-28

## Context

The brief asks for crop, rotate, adjustments and filters. Photos are up to 50 megapixels; the preview must follow a slider at 60 fps on the Galaxy A54, and the saved photo must look like the preview.

## Decision

- **The edit is plain data** (`PhotoEdit`, pure Dart): quarter turns, flip, a crop rectangle in fractions, adjustments from -1 to 1. Nothing is applied to pixels while editing.
- **Preview painted on a canvas** (`paintEdit`): the viewer's screen-sized preview decoded once, drawn turned, flipped and cropped with the color matrix as the paint's filter, the pencil lines on top. A first version used widgets (`RotatedBox`, `Transform.flip`, `ColorFiltered`); it was slow on the phone, see [editor.md](../features/editor.md#how-the-preview-works).
- **Colors as one 4 × 5 matrix** composed in pure Dart from the adjustments (and, in part 3, the filter): a slider only repaints.
- **Saving natively** (`PhotoSaver.kt`): decode the full photo, turn it upright, then flip, turn, draw it with Android's `ColorMatrixColorFilter` (the same 20 numbers) and the lines, in the order of `paintEdit`, crop, encode JPEG and insert it with MediaStore, EXIF copied.

## Alternatives considered

- **Editing pixels in Dart with the `image` package**: exact on every platform, but decoding and encoding a 12-megapixel photo takes seconds in an isolate, so the preview could not follow a slider; and saving would hold the full photo in Dart memory.
- **Shaders** (fragment programs): curves and local adjustments would be possible, but the five adjustments and the filters are linear per pixel, which a matrix does; a shader would need a separate path to save.
- **An editing package** (image_editor, pro_image_editor…): fast to add, but its look would not fit the app's design and its saving would bypass the app's rules (trash, EXIF, indexing).

## Consequences

- The preview and the saved photo share one matrix: what is seen is what is saved, up to rounding.
- Adjustments are limited to what a color matrix can do (no curves, highlights or shadows, no sharpening).
- Saving is `PlatformBridge.saveEditedPhoto` and the native `saveEditedPhoto`; the geometry is written twice (Dart and Kotlin) and must stay in the same order.
