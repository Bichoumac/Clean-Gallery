# Editor

Editing a photo and saving the result as a new photo: crop, straighten, rotate, flip; enhance, color adjustments, vignette; pencil, blur, pixelate; texts.

Last updated: 2026-10-29 — Milestone M6

## Purpose

The brief's "Editing and filters". Built in M6 part 2 (2026-10-28), then extended at the product owner's request: saving and a pencil (2026-10-29, after the first device test), then straighten, vignette, Enhance, Before/After, texts, blur and pixelate (2026-10-29). Filters (presets) remain for part 3.

## User flows

1. **Viewer → Edit** (sliders icon in the bottom bar, photos only): the editor opens full screen, dark, without ads. Top bar: ✕, **Before/After** (hold to see the original), **Reset**, **Save**. Bottom: the tool's controls, then four tool icons.
2. **Crop** (first icon): the whole photo with the crop frame (outside dimmed, thirds lines, lime corners).
   - Drag inside to move the crop, a corner to resize it (never below 10 % of a side, never outside).
   - Shapes: Free, Original, 1:1, 4:3, 3:4, 16:9, 9:16; picking one makes the largest crop of that shape around the center; corners then keep the shape.
   - **Straighten** slider, -45° to 45°: the photo turns and is enlarged just enough to leave no empty corner. Tap the value to go back to 0°.
   - **Rotate** (a quarter clockwise; 4:3 becomes 3:4) and **Flip** (left to right; the straightening is mirrored too).
3. **Adjust** (second icon): the cropped result. **Enhance** chip, then chips for Brightness, Contrast, Saturation, Exposure, Warmth, **Vignette** (a dot marks those in use) and one slider (-100 to 100) for the chip picked.
   - **Enhance** = automatic levels from the luminance histogram of the photo, no machine learning: the darkest 0.5 % of pixels become black and the lightest 0.5 % white (contrast capped at × 2, the slider's maximum), plus +10 saturation. The result is written into the Brightness, Contrast and Saturation sliders, so it can be refined.
   - **Vignette**: positive darkens the edges around the crop, negative lightens them.
4. **Draw** (third icon): brush **Pen** (six colors), **Blur** or **Pixels** (to hide a face or a plate); three widths each (areas are wider); **Undo** removes the last line. Lines turn, mirror and crop with the photo; color adjustments do not change pen lines, but blurred and pixelated areas keep them.
5. **Text** (fourth icon): **Add text** asks for the words (several lines allowed) and places them at the center. Tap a text to select it (lime frame), drag it to move it, double-tap it to change its words. For the selected text: **Edit text**, four fonts (Modern = Manrope, Classic = serif, Typewriter = monospace, Handwritten = cursive), **Bold**, **Delete**, a size slider, a text color row and a background row (None or a color: a rounded box behind the text).
6. **Save** asks how: **Save as a copy** (a new photo next to the original) or **Replace the original** (the new photo, and the original moved to the app trash, from where it can be restored). The editor closes, says so, and the viewer shows the new photo. On failure: *The photo couldn't be saved.*, the editor stays open.
7. **✕** or Back with changes asks *Discard your changes?*; without changes it closes at once.

## How it works

| Part | File | Role |
| --- | --- | --- |
| `PhotoEdit`, `CropRect`, `Adjustments`, `Stroke`, `TextItem`, `straightenScale`, crop math | [photo_edit.dart](../../lib/domain/photo_edit.dart) | The edit as plain data (pure Dart). Positions in fractions of the rotated, flipped photo; widths and text sizes in fractions of its shorter side, which turning does not change. `rotated()` and `mirrored()` move crop, lines and texts with the photo. |
| Color matrices | [color_matrix.dart](../../lib/analysis/color_matrix.dart) | One 4 × 5 matrix from the adjustments (exposure, brightness, contrast, saturation, warmth, in that order). |
| Enhance | [enhance.dart](../../lib/analysis/enhance.dart) | `luminanceHistogram`, `autoEnhance` (auto levels into sliders). |
| `paintEdit`, `renderEdit`, `EditSource` | [edit_painter.dart](../../lib/features/editor/edit_painter.dart) | Paints a photo edited: straighten, flip and turn with the color matrix; blurred areas (the photo redrawn with `ImageFilter.blur`, kept under the line with `BlendMode.dstIn`) and pixelated ones (a copy reduced to 40 squares across, drawn enlarged without smoothing); vignette (radial gradient); pen lines; texts (`TextPainter`). `renderEdit` paints at full size into an image. |
| `PhotoEditor` | [photo_editor.dart](../../lib/features/editor/photo_editor.dart) | Controller (Riverpod): rotate, flip, shape, crop drags, straighten, adjustments, strokes, texts, reset. |
| `EditorScreen` | [editor_screen.dart](../../lib/features/editor/editor_screen.dart) | Route `/editor` (`MediaItem` as `extra`); views (crop, result, drawing, texts), Before/After, Enhance, saving. Pops with the new photo's id. |
| Tool panels | [editor_tools.dart](../../lib/features/editor/editor_tools.dart) | `CropTools`, `AdjustTools`, `DrawTools`, `TextTools`, `ColorRow`. |

- **Preview**: the viewer's screen-sized preview, decoded once into an `EditSource`, painted by `paintEdit` in a `CustomPainter`. A slider only repaints. The first version stacked widgets (`RotatedBox`, `ColorFiltered`…): sliders were slow to start and to follow on the phone (product owner, 2026-10-28).
- **Saving**: the original is decoded at full size (at most 40 MP and 8192 px a side; a 50 MP photo is saved at about 40 MP), `renderEdit` paints the edit with the same `paintEdit` as the preview, and the RGBA pixels go to `PlatformBridge.saveEditedPhoto`. The native side ([PhotoSaver.kt](../../android/app/src/main/kotlin/com/bichoumac/clean_gallery/PhotoSaver.kt)) only encodes JPEG (quality 95), inserts it next to the original with its capture date (`<name>_edited_<time>.jpg`) and copies its EXIF tags (camera, settings, dates, GPS; orientation normal, new size). Then the index syncs and, for *Replace the original*, the original goes to the app trash ([ADR 0023](../decisions/0023-editor-color-matrix-preview.md)).
- Flutter's decoder applies the EXIF orientation, so the saved photo is upright and its orientation tag is set to normal.

## Edge cases

- A finger dragged past the opposite corner leaves the smallest crop, not a mirrored one.
- Straightening and then cropping: the crop is taken in the straightened photo.
- HEIC, PNG and WebP originals are saved as JPEG; transparency becomes black.
- A failed native save deletes the half-written row; the editor stays open with the edit.
- The text dialog owns its controller: it was disposed while the dialog was closing (crash in tests).

## Tests

- [photo_edit_test.dart](../../test/domain/photo_edit_test.dart): crop turning and mirroring, moves, shapes, corner drags, identity, oriented ratio, adjustments, strokes and texts following the photo, straighten scale covering the frame.
- [color_matrix_test.dart](../../test/analysis/color_matrix_test.dart), [enhance_test.dart](../../test/analysis/enhance_test.dart): each adjustment, composition, clamping; auto levels (stretch, × 2 cap, clipping of extremes, other adjustments kept), histogram.
- [editor_test.dart](../../test/features/editor/editor_test.dart): no Edit on videos, rotate and reset, sliders, closing with and without changes, 1:1, corner drag, pencil and undo, straighten, Enhance and Vignette, Before/After, blur brush, texts (add, font, bold, move, delete), Save as a copy, Replace the original.
- Rendering and the native save are checked on the device ([testing.md](../testing.md#m6--viewer-and-editing-to-verify-on-a-device)).

## Known limitations / future work

- Filters (presets combining a matrix with the adjustments): part 3 of M6.
- Texts cannot be turned; no eraser for the pencil (Undo removes whole lines); blur and pixelate areas are drawn under the pen lines whatever the order they were made in.
- No batch editing (product owner, 2026-10-29: not wanted for now).
