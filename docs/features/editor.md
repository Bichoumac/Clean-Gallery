# Editor

Editing a photo: crop, rotate, flip and color adjustments, then (part 3 of M6) filters and saving.

Last updated: 2026-10-28 — Milestone M6 (part 2)

## Purpose

The brief's "Editing and filters": crop, rotate, adjustments, filters. Part 2 (this page) builds the editor and its live preview; part 3 adds the filters and saves the result as a new photo.

## User flows

1. **Viewer → Edit** (sliders icon in the top bar, photos only): the editor opens full screen, dark like the viewer, without ads.
2. **Crop** tool (the default): the whole photo with the crop on top, the outside dimmed, thirds lines and lime corners.
   - Drag inside the crop to move it; drag a corner to resize it (never below a tenth of the photo's side, never outside).
   - Shapes: **Free**, **Original** (the photo's proportions), **1:1**, **4:3**, **3:4**, **16:9**, **9:16**. Picking one makes the crop the largest of that shape around its center; corners then keep the shape.
   - **Rotate** turns the photo a quarter clockwise (the crop turns with it, and 4:3 becomes 3:4); **Flip** mirrors it left to right.
3. **Adjust** tool: the cropped result as large as it fits; chips for **Brightness**, **Contrast**, **Saturation**, **Exposure** and **Warmth** (a dot marks those in use) and one slider from -100 to 100 for the chip picked. The preview follows the slider live.
4. **Reset** (top right) returns to the photo as it was.
5. **Close** (or Back) with changes asks *Discard your changes?* — *Keep editing* or *Discard*; without changes it closes at once.
6. **Saving** comes in part 3: until then the editor never changes the photo.

## How the preview works

- The edit is plain data ([photo_edit.dart](../../lib/domain/photo_edit.dart), pure Dart): quarter turns, flip, crop rectangle (fractions of the rotated and flipped photo) and five adjustments from -1 to 1, applied in that order.
- The image is the viewer's screen-sized preview, rotated (`RotatedBox`), flipped (`Transform.flip`) and stretched to its box; the crop is a `ClipRect` around the photo shifted and scaled so that the crop fills the box.
- Colors: one 4 × 5 color matrix composed from the five adjustments ([color_matrix.dart](../../lib/analysis/color_matrix.dart), pure Dart) in a `ColorFilter.matrix`, so moving a slider only repaints: the photo is never decoded or encoded again. Android's `ColorMatrix` takes the same 20 numbers, so the saved photo will match the preview ([ADR 0023](../decisions/0023-editor-color-matrix-preview.md)).

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
- The preview is screen-sized: the saved photo (part 3) is computed from the full photo natively.

## Tests

- [photo_edit_test.dart](../../test/domain/photo_edit_test.dart): crop turning and mirroring with the photo, moving, shapes, corner drags (free, fixed, minimum, edges), identity, oriented ratio, adjustments.
- [color_matrix_test.dart](../../test/analysis/color_matrix_test.dart): identity, composition order, each adjustment's effect, clamping, gray kept by saturation, alpha untouched.
- [editor_test.dart](../../test/features/editor/editor_test.dart): no Edit button on videos, rotate and reset, an adjustment coloring the preview, closing with and without changes, a 1:1 crop, dragging a corner.

## Known limitations / future work

- No saving yet (part 3): saving natively, *Save as copy* by default, *Replace original* through the app trash, EXIF kept.
- No filters yet (part 3).
- No free rotation (straightening by a few degrees), no vertical flip.
