# Viewer

Full-screen photo and video viewer, opened from any grid.

Last updated: 2026-10-28 — Milestone M6

## Purpose

Show one item at a time, full screen, with swiping between the items of the grid it was opened from. Photos zoom by pinching or double-tapping; videos play with Clean Gallery's own controls.

## User flows

1. Tap a thumbnail: the image flies from the grid to full screen (Hero transition).
2. Swipe left or right to move between items, in the grid's order, including its sort and date filter.
3. Pinch, or double-tap, to zoom a photo; double-tap again to fit. Swiping is disabled while zoomed.
4. Tap once to hide or show the controls and the system bars.
5. Videos start playing when they become the current page and pause when swiped away. Controls: play/pause/replay, progress bar with seeking, mute, rotate. The progress bar follows the finger and the video seeks when it is lifted.
6. Top bar actions: **share**, **favorite**, **details** (the [info panel](#info-panel)), **move to trash** (with *Undo*); after trashing, the next item is shown, and the viewer closes when nothing is left.
7. Back returns to the grid.

## Screens and widgets

| Widget | File |
| --- | --- |
| `ViewerScreen` (pages, top bar, system UI) | [viewer_screen.dart](../../lib/features/viewer/viewer_screen.dart) |
| `ZoomableImage` (photo page) | [zoomable_image.dart](../../lib/features/viewer/zoomable_image.dart) |
| `VideoPage` and its controls | [video_page.dart](../../lib/features/viewer/video_page.dart) |
| `InfoPanel`, `showInfoPanel` | [info_panel.dart](../../lib/features/viewer/info_panel.dart) |

Route: `/viewer`, above the tabs, with `ViewerArgs(selection, initialIndex)` as `extra` ([app_router.dart](../../lib/core/router/app_router.dart)). Without arguments (e.g. restored after the process was killed), it redirects to Photos.

## State and data

- Items come from `mediaListProvider(selection)`, the same list as the grid, so nothing is loaded twice and indexes match.
- Photos: the grid thumbnail is shown instantly, then a **screen-sized preview** (`MediaSource.preview`, decoded from the photo file at that size by Android's `ImageDecoder`, as raw pixels) at the size the photo takes once fitted in the screen (`viewerPreviewSide`), at most 2,560 px and never larger than the photo. Until 2026-10-27 it was the screen's longest side whatever the photo's shape: about four times the pixels for a landscape photo on a portrait screen, and the product owner saw photos stay blurry a moment before turning sharp. The previews of the neighbouring photos are requested only once the shown photo's preview is ready, since the native loader serves the newest request first. While the viewer is open, the duplicate scan is paused (`DuplicateScan.pause`): MediaStore renders thumbnails almost one at a time, so the scan's would delay the photo being opened. The full-resolution image (`MediaSource.fullImage`, at most 4,096 px) is only loaded once the user zooms past 1.3×.
- Previews came from MediaStore's thumbnail cache until 2026-10-27, but on the Galaxy A54 that cache stops at 512 px: asked for 1080 × 1440, it returned 384 × 512 in about 30 ms, stretched and blurry until the user zoomed in (measured on the device). Decoding the file takes 0.3 to 0.7 s for a 12 MP photo and stays sharp; grid thumbnails still come from the cache, which is about ten times faster.
- Previews of the next, previous and second-next photos are precached when a page is shown, so swiping lands on a ready image.
- Videos: `MediaSource.videoUri` (a `content://` URI) played by `video_player` ([ADR 0011](../decisions/0011-video-playback.md)).
- Zoom: own gesture handling ([ADR 0010](../decisions/0010-photo-zoom.md)): one finger swipes between pages at fit scale and pans once zoomed; two fingers zoom. The zoom claims the gesture as soon as the second finger lands: otherwise a pinch whose first finger slid a little first went to the page view and did not zoom (seen on the device on 2026-10-27).
- The top bar is pinned to the top with its own height: an earlier full-screen overlay swallowed swipes and the video controls.

## Info panel

The brief: "a bottom sheet that slides up with a translucent blurred background over the photo. It shows the date (and its source), file name, path, size, resolution, camera, lens, ISO, aperture, shutter speed, focal length, and GPS location with a mini map."

- Opened with the **details** button (ⓘ) of the top bar; closed by swiping it down, tapping the photo above it, or Back.
- A modal bottom sheet over a `BackdropFilter` blur (σ 30) and 55 % black, at most 90 % of the screen high, scrolling when longer. Its content ends above the system navigation bar: the sheet is drawn edge to edge, and on the device the last rows were hidden under that bar at first (75 % high, no bottom inset; product owner, 2026-10-27).
- What the index already knows shows at once: date, name, path, resolution and megapixels, size, video duration. The rest is read when the panel opens (`mediaInfoProvider` in [media_info.dart](../../lib/features/viewer/media_info.dart)), with a small spinner until then:
  - **Date source**, from the media index (`MediaIndexRepository.dateSource`): *From the photo's metadata (EXIF)*, *From the file name*, or *File date* (also when corrected dates are turned off in Settings, since the date shown is then the system's);
  - **Camera metadata**, from the file's EXIF header (`MediaSource.metadata`, native `mediaMetadata`, [platform-android.md](../platform-android.md#native-channel-clean_galleryplatform)): camera (maker and model, the maker once), lens, then ISO, aperture (`f/1.8`), shutter speed (`1/125 s`) and focal length (`5.4 mm · 24 mm equivalent`) as small tiles;
  - **Location**, as latitude and longitude with five decimals: tapping it opens the user's map app on that point (a `geo:` intent, `PlatformBridge.openMap`; when no app handles it, the panel closes and a snack bar says so), and a copy button puts the coordinates on the clipboard. Videos only have a location.
- Missing values are left out. A photo with no camera data at all says *No camera information in this file.*; without the media location permission, the location row says to allow it in Settings (Android hides GPS tags from apps without it).
- **Quality** (photos): the last row shows the analysis engine's measures on the photo's 256-pixel grayscale thumbnail, read when the panel opens (`photoQualityProvider`): `S 42 · N 180 · B 35 · C 22` for sharpness, relative sharpness, brightness and contrast ([analysis-engine.md](../analysis-engine.md#blurry-and-dark-photos)), and under it whether the photo is offered as blurry or too dark. Asked by the product owner after the blur calibration, to check the thresholds on real photos.
- **Mini map** (M6, with the map brought forward): below the coordinates, a still OpenStreetMap map of the point with a lime dot; tapping it opens the app's map there ([map.md](map.md)). Its tiles need the network; without it the dot shows on a grey background.

## Edge cases and error handling

- **Unreadable file or video**: "This item can't be displayed." on that page; other pages still work.
- **Very large photos**: decode size is capped, so a 200 MP image never allocates hundreds of megabytes.
- **Rotation**: the rotate button forces landscape or portrait; leaving the viewer restores free rotation and the system bars.
- **List grows while open** (background chunks): the current index is kept; pages beyond appear as they load.
- The viewer is always dark, whatever the app theme.

## Tests

- [library_test.dart](../../test/features/library/library_test.dart): opening the viewer on the tapped item, showing its file name, closing with back.
- [viewer_test.dart](../../test/features/viewer/viewer_test.dart): swipe left and right (fling and slow drag), pinch then pan without changing page, double-tap back to fit, top bar height.
- [info_panel_test.dart](../../test/features/viewer/info_panel_test.dart): the panel with camera settings and location, the location reached at the end and opening a map, the notes for missing camera data and location permission, the quality row, value formats.
- [video_controls_test.dart](../../test/features/viewer/video_controls_test.dart): progress bar at the bottom and play button centered, in portrait and landscape (the bar was in the middle of the screen because `Slider` takes all the height it is given).
- Video playback, zoom gestures and Hero transitions are checked on a device ([testing.md](../testing.md#m1--to-verify-on-a-device)).

## Known limitations / future work

- Edit comes later in M6.
- Zoom is limited to 5× and to the 4,096 px decoded image.
