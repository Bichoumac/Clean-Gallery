# Viewer

Full-screen photo and video viewer, opened from any grid.

Last updated: 2026-10-25 — Milestone M1

## Purpose

Show one item at a time, full screen, with swiping between the items of the grid it was opened from. Photos zoom by pinching or double-tapping; videos play with Clean Gallery's own controls.

## User flows

1. Tap a thumbnail: the image flies from the grid to full screen (Hero transition).
2. Swipe left or right to move between items, in the grid's order.
3. Pinch, or double-tap, to zoom a photo; double-tap again to fit. Swiping is disabled while zoomed.
4. Tap once to hide or show the controls and the system bars.
5. Videos start playing when they become the current page and pause when swiped away. Controls: play/pause/replay, progress bar with seeking, mute, rotate.
6. Back returns to the grid.

## Screens and widgets

| Widget | File |
| --- | --- |
| `ViewerScreen` (pages, top bar, system UI) | [viewer_screen.dart](../../lib/features/viewer/viewer_screen.dart) |
| `ZoomableImage` (photo page) | [zoomable_image.dart](../../lib/features/viewer/zoomable_image.dart) |
| `VideoPage` and its controls | [video_page.dart](../../lib/features/viewer/video_page.dart) |

Route: `/viewer`, above the tabs, with `ViewerArgs(selection, initialIndex)` as `extra` ([app_router.dart](../../lib/core/router/app_router.dart)). Without arguments (e.g. restored after the process was killed), it redirects to Photos.

## State and data

- Items come from `mediaListProvider(selection)`, the same list as the grid, so nothing is loaded twice and indexes match.
- Photos: `MediaSource.fullImage`, decoded at most 4,096 px on the longest side; the 512 px thumbnail is shown until it is ready.
- Videos: `MediaSource.videoUri` (a `content://` URI) played by `video_player` ([ADR 0011](../decisions/0011-video-playback.md)).
- Zoom: Flutter's `InteractiveViewer` ([ADR 0010](../decisions/0010-photo-zoom.md)).

## Edge cases and error handling

- **Unreadable file or video**: "This item can't be displayed." on that page; other pages still work.
- **Very large photos**: decode size is capped, so a 200 MP image never allocates hundreds of megabytes.
- **Rotation**: the rotate button forces landscape or portrait; leaving the viewer restores free rotation and the system bars.
- **List grows while open** (background chunks): the current index is kept; pages beyond appear as they load.
- The viewer is always dark, whatever the app theme.

## Tests

- [library_test.dart](../../test/features/library/library_test.dart): opening the viewer on the tapped item, showing its file name, closing with back.
- Video playback, zoom gestures and Hero transitions are checked on a device ([testing.md](../testing.md#m1--to-verify-on-a-device)).

## Known limitations / future work

- Action bar (share, favorite, edit, info, delete) comes in M2 and M6.
- The info panel with EXIF data and a mini map comes in M6.
- Zoom is limited to 5× and to the 4,096 px decoded image.
