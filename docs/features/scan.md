# Document scanner

Turning a photo of a document into a flat, readable page, saved as a new photo.

Last updated: 2026-11-04 — Visual refresh

## Purpose

Asked by the product owner on 2026-10-29, from an existing photo (not the camera: no new permission). Detection by plain image processing, no machine learning ([ADR 0024](../decisions/0024-document-scanner.md)).

## User flows

1. **Viewer → Scan a document** (page icon in the top bar, photos only).
2. **Corners**: the photo with the page outlined in the accent color and four round handles; the outside dimmed. *Page found: drag a corner to adjust it.*, or, when no page stands out, the corners 8 % in and *Drag the four corners onto the page's corners.* Drag a handle to move it (it grabs within 48 px).
3. **Next**: the page flattened (the perspective undone), sized by its longer opposite sides. Modes: **Color** (light stretched), **Gray**, **Black & white** (median paper white, darkest 2 % black: shadows and yellowed paper go). Back returns to the corners.
4. **Save**: a new photo next to the original (same folder, capture date and EXIF as the editor's copies), *Scan saved*, and the viewer shows it. The original stays.

## How it works

- [document.dart](../../lib/analysis/document.dart) (pure Dart): `grayFromRgba` (≤ 200 px), `detectDocument` (Otsu threshold, largest light area in one piece covering 10 % to 97 % of the image, its points furthest along the diagonals as corners), `homography` (8 × 8 solve), `pageSize`, `documentMatrix` (levels from the page's histogram, gray matrix).
- [scan_screen.dart](../../lib/features/scan/scan_screen.dart): route `/scan` (`MediaItem` as `extra`). `paintPage` draws the photo through the homography as a 4 × 4 canvas transform (perspective on the GPU) with the mode's color matrix; `renderPage` does it at full size (≤ 40 MP, ≤ 8192 px) for saving through `PlatformBridge.saveEditedPhoto`, like the editor.
- The histogram for the modes is measured once on a 600 px flattened preview when entering the page step.

## Edge cases

- A sheet on a light table, a folded sheet, or a page filling the whole photo is not found: the user places the corners.
- Corners in a crossed order give a twisted page; the user fixes them (no reordering is done).

## Tests

- [document_test.dart](../../test/analysis/document_test.dart): corners of a tilted sheet, no sheet, homography, page size, Otsu, black and white, gray.
- [scan_test.dart](../../test/features/scan/scan_test.dart): corners to place on a blank photo, a corner dragged, black and white, saved and shown in the viewer; Back from the page to the corners.

## Look

Same dark screen and accent rules as the editor. [Mockup](../design-assets/mockups/screens/14-editor.png).

## Known limitations / future work

- No camera capture (product owner's choice, 2026-10-29).
- No magnifier under the finger while placing a corner; no multi-page PDF.
