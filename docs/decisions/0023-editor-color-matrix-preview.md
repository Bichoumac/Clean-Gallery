# ADR 0023 — Editor: the edit as data, colors as one matrix, saving natively

How the editor previews changes live and how they will be saved.

Last updated: 2026-10-29 — Milestone M6

- **Status**: Accepted
- **Date**: 2026-10-28

## Context

The brief asks for crop, rotate, adjustments and filters. Photos are up to 50 megapixels; the preview must follow a slider at 60 fps on the Galaxy A54, and the saved photo must look like the preview.

## Decision

- **The edit is plain data** (`PhotoEdit`, pure Dart): quarter turns, flip, a crop rectangle in fractions, adjustments from -1 to 1. Nothing is applied to pixels while editing.
- **Preview painted on a canvas** (`paintEdit`): the viewer's screen-sized preview decoded once, drawn turned, flipped and cropped with the color matrix as the paint's filter, the pencil lines on top. A first version used widgets (`RotatedBox`, `Transform.flip`, `ColorFiltered`); it was slow on the phone, see [editor.md](../features/editor.md#how-it-works).
- **Colors as one 4 × 5 matrix** composed in pure Dart from the adjustments (and, in part 3, the filter): a slider only repaints.
- **Saving: Flutter renders, Android writes** (since 2026-10-29): the original decoded at full size is painted by the same `paintEdit` as the preview into an image; its RGBA pixels go to the native `saveEditedPhoto`, which encodes JPEG, inserts it with MediaStore and copies the EXIF tags. A first version (2026-10-29 morning) redid the geometry and colors in Kotlin; texts, blur and pixelate would have needed a second implementation of each, so the rendering moved to Flutter.

## Alternatives considered

- **Editing pixels in Dart with the `image` package**: exact on every platform, but decoding and encoding a 12-megapixel photo takes seconds in an isolate, so the preview could not follow a slider; and saving would hold the full photo in Dart memory.
- **Shaders** (fragment programs): curves and local adjustments would be possible, but the five adjustments and the filters are linear per pixel, which a matrix does; a shader would need a separate path to save.
- **An editing package** (image_editor, pro_image_editor…): fast to add, but its look would not fit the app's design and its saving would bypass the app's rules (trash, EXIF, indexing).

## Consequences

- The preview and the saved photo come from one function: what is seen is what is saved, at another resolution.
- Saving holds the full photo and its edited copy in memory (about 2 × 48 MB for 12 MP; capped at 40 MP) and sends the pixels over the platform channel.
- Adjustments are limited to what a color matrix can do (no curves, highlights or shadows, no sharpening).
- Saving is `PlatformBridge.saveEditedPhoto(photo, width, height, rgba)`; the document scanner uses it too ([ADR 0024](0024-document-scanner.md)).
