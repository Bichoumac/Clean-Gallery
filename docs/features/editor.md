# Editor

Editing a photo: crop, rotate, flip, color adjustments and a pencil, saved as a new photo; filters come in part 3 of M6.

Last updated: 2026-10-29 — Milestone M6 (part 2, saving brought forward)

## Purpose

The brief's "Editing and filters": crop, rotate, adjustments, filters. Part 2 built the editor and its live preview; after the first device test (2026-10-29) the product owner asked for saving (planned for part 3) and a pencil at once. Filters remain for part 3.

## User flows

1. **Viewer → Edit** (sliders icon in the bottom bar, photos only): the editor opens full screen, dark like the viewer, without ads.
2. **Crop** tool (the default): the whole photo with the crop on top, the outside dimmed, thirds lines and lime corners.
   - Drag inside the crop to move it; drag a corner to resize it (never below a tenth of the photo's side, never outside).
   - Shapes: **Free**, **Original** (the photo's proportions), **1:1**, **4:3**, **3:4**, **16:9**, **9:16**. Picking one makes the crop the largest of that shape around its center; corners then keep the shape.
   - **Rotate** turns the photo a quarter clockwise (the crop turns with it, and 4:3 becomes 3:4); **Flip** mirrors it left to right.
3. **Adjust** tool: the cropped result as large as it fits; chips for **Brightness**, **Contrast**, **Saturation**, **Exposure** and **Warmth** (a dot marks those in use) and one slider from -100 to 100 for the chip picked. The preview follows the slider live.
4. **Draw** tool: the cropped result; a finger draws lines in one of six colors (white, black, lime, red, yellow, blue) and three widths; **Undo** removes the last line. Lines turn, mirror and crop with the photo, and are not touched by the color adjustments.
5. **Reset** (top right) returns to the photo as it was.
6. **Save** (top right, once something changed) asks how: **Save as a copy** (a new photo next to the original) or **Replace the original** (the new photo, and the original moved to the app trash, from where it can be restored). The editor closes, says *Copy saved* or *Photo replaced; the original is in the trash*, and the viewer shows the new photo. On failure: *The photo couldn't be saved.*, the editor stays open.
7. **Close** (or Back) with changes asks *Discard your changes?* — *Keep editing* or *Discard*; without changes it closes at once.

## How the preview works

- The edit is plain data ([photo_edit.dart](../../lib/domain/photo_edit.dart), pure Dart): quarter turns, flip, crop rectangle (fractions of the rotated and flipped photo) and five adjustments from -1 to 1, applied in that order.
- The image is the viewer's screen-sized preview, decoded once into a `ui.Image`. `paintEdit` paints it on a canvas: placed so that the part shown fills the box (the whole photo while cropping, the crop otherwise), flipped, turned, drawn with the edit's color matrix as the paint's color filter, then the pencil lines on top.
- Colors: one 4 × 5 color matrix composed from the five adjustments ([color_matrix.dart](../../lib/analysis/color_matrix.dart), pure Dart). Moving a slider only repaints the canvas: no image is decoded, no widget is rebuilt around it, no layer is added ([ADR 0023](../decisions/0023-editor-color-matrix-preview.md)).
- **Why a canvas**: the first version stacked widgets (`RotatedBox`, `Transform.flip`, `ColorFiltered`); on the phone, sliders were slow to start and to follow a fast finger (product owner, 2026-10-28). The first slider move inserted the `ColorFiltered` layer, which rebuilt the image under it, and each change repainted through an offscreen layer. The canvas draws the image once per frame with the filter in its paint.

## Saving

`PlatformBridge.saveEditedPhoto` sends the edit and its color matrix to the native method `saveEditedPhoto` ([PhotoSaver.kt](../../android/app/src/main/kotlin/com/bichoumac/clean_gallery/PhotoSaver.kt), [platform-android.md](../platform-android.md#native-channel-clean_galleryplatform)):

1. Decode the original in full, halved as often as needed to stay under 40 megapixels (a 50 MP photo is saved at 12.5 MP), and turn it upright as its EXIF orientation says.
2. On a canvas the size of the crop: flip, turn, draw with Android's `ColorMatrixColorFilter` (the same 20 numbers as the preview), then the pencil lines — the order of `paintEdit`.
3. Encode JPEG (quality 95) and insert it with MediaStore in the original's folder, named `<name>_edited_<time>.jpg`, with the original's capture date so it sorts next to it; pending until written.
4. Copy the original's EXIF tags (camera, settings, dates, GPS when the location permission allows reading them), orientation set to normal, the new size, software "Clean Gallery".
5. The app syncs its index; *Replace the original* then moves the original to the app trash (never deleted directly, rule 2 of AGENTS.md).

| Adjustment | Matrix | At -100 | At 100 |
| --- | --- | --- | --- |
| Exposure | × 2^value | One stop darker (× 0.5) | One stop brighter (× 2) |
| Brightness | + value × 64 | -64 | +64 |
| Contrast | around mid-gray | × 0.25 (flat) | × 2 |
| Saturation | Rec. 709 luminance kept | Black and white | Colors doubled |
| Warmth | red × (1 + 0.12 v), blue × (1 − 0.12 v) | Cooler | Warmer |

Applied in the order of the table.

## Screens and widgets

| Widget | File | Role |
| --- | --- | --- |
| `EditorScreen` | [editor_screen.dart](../../lib/features/editor/editor_screen.dart) | Route `/editor` (`MediaItem` as `extra`): top bar, preview, tools, tool switch |
| `PhotoEditor` | [photo_editor.dart](../../lib/features/editor/photo_editor.dart) | Controller: the `PhotoEdit` and the crop shape; rotate, flip, shape, crop drags, adjustments, reset |

## Edge cases

- A finger dragged past the opposite corner leaves the smallest crop, not a mirrored one.
- A fixed shape that does not fit as dragged is limited by the photo's edge.
- The preview is screen-sized: the saved photo is computed from the full photo natively.
- HEIC, PNG and WebP originals are saved as JPEG.
- A save that fails removes the half-written photo.

## Tests

- [photo_edit_test.dart](../../test/domain/photo_edit_test.dart): crop turning and mirroring with the photo, moving, shapes, corner drags (free, fixed, minimum, edges), identity, oriented ratio, adjustments.
- [color_matrix_test.dart](../../test/analysis/color_matrix_test.dart): identity, composition order, each adjustment's effect, clamping, gray kept by saturation, alpha untouched.
- [editor_test.dart](../../test/features/editor/editor_test.dart): no Edit button on videos, rotate and reset, a slider, closing with and without changes, a 1:1 crop, dragging a corner, drawing and undoing lines, *Save as a copy* showing the new photo, *Replace the original* trashing it.
- The native save (geometry, colors, EXIF) is checked on the device ([testing.md](../testing.md#m6--viewer-and-editing-to-verify-on-a-device)).

## Known limitations / future work

- No filters yet (part 3).
- Very large photos (over 40 MP) are saved at a lower resolution.
- The pencil has no eraser; Undo removes whole lines.
- No free rotation (straightening by a few degrees), no vertical flip.
