# Viewer

Full-screen photo and video viewer, opened from any grid.

Last updated: 2026-10-25 — Milestone M2

## Purpose

Show one item at a time, full screen, with swiping between the items of the grid it was opened from. Photos zoom by pinching or double-tapping; videos play with Clean Gallery's own controls.

## User flows

1. Tap a thumbnail: the image flies from the grid to full screen (Hero transition).
2. Swipe left or right to move between items, in the grid's order, including its sort and date filter.
3. Pinch, or double-tap, to zoom a photo; double-tap again to fit. Swiping is disabled while zoomed.
4. Tap once to hide or show the controls and the system bars.
5. Videos start playing when they become the current page and pause when swiped away. Controls: play/pause/replay, progress bar with seeking, mute, rotate. The progress bar follows the finger and the video seeks when it is lifted.
6. Top bar actions: **share**, **favorite**, **move to trash** (with *Undo*); after trashing, the next item is shown, and the viewer closes when nothing is left.
7. Back returns to the grid.

## Screens and widgets

| Widget | File |
| --- | --- |
| `ViewerScreen` (pages, top bar, system UI) | [viewer_screen.dart](../../lib/features/viewer/viewer_screen.dart) |
| `ZoomableImage` (photo page) | [zoomable_image.dart](../../lib/features/viewer/zoomable_image.dart) |
| `VideoPage` and its controls | [video_page.dart](../../lib/features/viewer/video_page.dart) |

Route: `/viewer`, above the tabs, with `ViewerArgs(selection, initialIndex)` as `extra` ([app_router.dart](../../lib/core/router/app_router.dart)). Without arguments (e.g. restored after the process was killed), it redirects to Photos.

## State and data

- Items come from `mediaListProvider(selection)`, the same list as the grid, so nothing is loaded twice and indexes match.
- Photos: the grid thumbnail is shown instantly, then a **screen-sized preview** (`MediaSource.preview`, from MediaStore's thumbnail cache as raw pixels) at the size the photo takes once fitted in the screen (`viewerPreviewSide`), at most 2,560 px and never larger than the photo. Until 2026-10-27 it was the screen's longest side whatever the photo's shape: about four times the pixels for a landscape photo on a portrait screen, and the product owner saw photos stay blurry a moment before turning sharp. The previews of the neighbouring photos are requested only once the shown photo's preview is ready, since the native loader serves the newest request first. The full-resolution image (`MediaSource.fullImage`, at most 4,096 px) is only loaded once the user zooms past 1.3×.
- Previews of the next, previous and second-next photos are precached when a page is shown, so swiping lands on a ready image.
- Videos: `MediaSource.videoUri` (a `content://` URI) played by `video_player` ([ADR 0011](../decisions/0011-video-playback.md)).
- Zoom: own gesture handling ([ADR 0010](../decisions/0010-photo-zoom.md)): one finger swipes between pages at fit scale and pans once zoomed; two fingers zoom.
- The top bar is pinned to the top with its own height: an earlier full-screen overlay swallowed swipes and the video controls.

## Edge cases and error handling

- **Unreadable file or video**: "This item can't be displayed." on that page; other pages still work.
- **Very large photos**: decode size is capped, so a 200 MP image never allocates hundreds of megabytes.
- **Rotation**: the rotate button forces landscape or portrait; leaving the viewer restores free rotation and the system bars.
- **List grows while open** (background chunks): the current index is kept; pages beyond appear as they load.
- The viewer is always dark, whatever the app theme.

## Tests

- [library_test.dart](../../test/features/library/library_test.dart): opening the viewer on the tapped item, showing its file name, closing with back.
- [viewer_test.dart](../../test/features/viewer/viewer_test.dart): swipe left and right (fling and slow drag), pinch then pan without changing page, double-tap back to fit, top bar height.
- [video_controls_test.dart](../../test/features/viewer/video_controls_test.dart): progress bar at the bottom and play button centered, in portrait and landscape (the bar was in the middle of the screen because `Slider` takes all the height it is given).
- Video playback, zoom gestures and Hero transitions are checked on a device ([testing.md](../testing.md#m1--to-verify-on-a-device)).

## Known limitations / future work

- Edit and the info panel come in M6.
- The info panel with EXIF data and a mini map comes in M6.
- Zoom is limited to 5× and to the 4,096 px decoded image.
