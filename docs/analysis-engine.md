# Analysis engine

Algorithms that work out facts about photos and videos on the device: capture dates, exact duplicates, bursts, similar photos, screenshots, and blurry or dark photos. This file lists each algorithm, its thresholds and their rationale, and performance notes.

Last updated: 2026-10-27 — Milestone M5

## Overview

| Step | Status | Where | Stored in |
| --- | --- | --- | --- |
| Capture date | Done (M3) | [capture_date.dart](../lib/analysis/capture_date.dart), applied by the media index sync | `assets.capture_at`, `capture_source` |
| Exact duplicates | Done (M3) | [duplicates.dart](../lib/core/media/duplicates.dart), hashing in [MediaIndex.kt](../android/app/src/main/kotlin/com/bichoumac/clean_gallery/MediaIndex.kt) | `content_hash`, `duplicate_groups` |
| Bursts | Done (M3) | [burst.dart](../lib/analysis/burst.dart), applied by the media index sync; groups by `DuplicateScan` | `burst_id`, `duplicate_groups` |
| Similar photos | Done (M4) | [perceptual_hash.dart](../lib/analysis/perceptual_hash.dart), [similarity.dart](../lib/analysis/similarity.dart), [hash_index.dart](../lib/analysis/hash_index.dart); pixels from [MediaIndex.kt](../android/app/src/main/kotlin/com/bichoumac/clean_gallery/MediaIndex.kt) | `d_hash`, `p_hash`, `analysis_version`, `duplicate_groups`, `ignored_pairs` |
| Screenshots | Done (M5) | [screenshot.dart](../lib/analysis/screenshot.dart), applied by the media index sync | `is_screenshot` |
| Blurry and dark photos | Done (M5) | [image_quality.dart](../lib/analysis/image_quality.dart), measured with the hashes | `blur_score`, `brightness` |

Code in `lib/analysis/` is pure Dart: no Flutter import, so it can run in an isolate and be tested without a device (a test enforces it).

**Where the work runs.** The brief asks for an engine in an isolate, incremental and resumable. SQL (grouping, candidates) runs in Drift's background isolate; file hashing and thumbnail rendering on a native thread; perceptual hashes and the similar photo search in a Dart isolate (`Isolate.run`, through `analysisRunnerProvider`). What runs on the UI isolate is per-item rule matching during a sync (two regular expressions on a file name), well under a millisecond per item. Results are saved as they go, so an interrupted sync or scan resumes; **Settings → Analyze the library again** forgets them all and starts over (pairs marked "Not duplicates" are kept: they are the user's decisions).

**Order of a scan** (`DuplicateScan`, after each index sync): content hashes of size collisions → exact and burst groups (shown at once) → perceptual hashes, sharpness and brightness of new photos → similar groups.

## Capture date

The date a photo or video was taken. Timelines sort and group by it unless the user turns **Corrected dates** off in Settings ([settings.md](features/settings.md)); duplicates and bursts will use it too.

### Rules

`resolveCaptureDate` picks the first of:

| Order | Source (`capture_source`) | Read from | Example |
| --- | --- | --- | --- |
| 1 | `exif` | The date MediaStore read from the file's metadata (`DATE_TAKEN`: EXIF `DateTimeOriginal` for photos, the creation time for videos) | A camera photo |
| 2 | `filename` | A date in the file name | `IMG-20240315-WA0001.jpg` → March 15, 2024 |
| 3 | `file` | The date the file was added to the device (`DATE_ADDED`) | `photo.jpg` without metadata |

The platform date (`taken_at`, rule 1 or 3) is kept next to the resolved one, so the setting can switch between them without a new sync.

### File name patterns

A date is `YYYYMMDD`, `YYYY-MM-DD`, `YYYY_MM_DD` or `YYYY.MM.DD` (same separator twice), optionally followed by a time `HHMMSS`, `HH-MM-SS`, `HH.MM.SS` or `HH:MM:SS`, and up to three digits of milliseconds. It must not touch other digits, so ids and counters are not read as dates.

| File name | Date |
| --- | --- |
| `IMG_20240315_142233.jpg`, `20240315_142233.jpg` (Samsung camera), `PXL_20240315_142233123.jpg` | March 15, 2024, 14:22:33 |
| `Screenshot_20240315-142233_Chrome.jpg`, `Screenshot_2024-03-15-14-22-33-123_com.app.jpg` | same |
| `signal-2024-03-15-142233.jpg`, `PHOTO-2024-03-15-14-22-33.jpg` | same |
| `IMG-20240315-WA0001.jpg`, `VID-20240315-WA0007.mp4` (WhatsApp) | March 15, 2024, noon, or the time it was received if that was the same day |
| `IMG_1234.JPG`, `DSC00042.JPG`, `1710512553000.jpg` | none |

Rejected: invalid days (February 30), years before 1990, dates in the future. Times are local, like the camera's.

### Thresholds and rationale

- **Date without a time → noon**: keeps the photo in the right day whatever the time zone shift, and in the middle of it. When the file arrived the same day, its arrival time is more precise and is kept.
- **`DATE_TAKEN` within 2 seconds of `DATE_ADDED` or `DATE_MODIFIED` is not trusted as metadata**: some devices fill `DATE_TAKEN` with the file date when the file has no EXIF, which would hide the date in the file name. For a camera photo saved right away, the file name (or the same `DATE_TAKEN`) gives the same date, so nothing is lost ([android_media_source.dart](../lib/platform/android/android_media_source.dart)).
- **1990**: older dates in a name are much more likely to be counters.

### When dates are resolved

During the media index sync, for each new or changed item, from the metadata the sync reads anyway: no file is opened ([ADR 0016](decisions/0016-capture-dates-at-index-time.md)). `indexRulesVersion` ([index_rules.dart](../lib/analysis/index_rules.dart)) versions the rules applied at index time (capture dates, [burst ids](#bursts) and [screenshots](#screenshots)); when it is bumped, the next sync describes every item again and applies them, keeping other analysis results. The version the index was built with is stored in the `index_rules` setting.

### Performance

Resolving a date is a regular expression on the file name: well under a millisecond per item, inside a sync that already reads the item's metadata. A full re-resolution of 30,000 items costs one full sync (the same as the first launch).

## Exact duplicates

Items whose content is byte-for-byte identical ([ADR 0017](decisions/0017-exact-duplicates-sha256.md)).

1. **Candidates**: items with no hash yet whose size (`size_bytes > 0`) is shared by another item, outside the trash, smallest first.
2. **Hash**: SHA-256 of the whole file, computed natively, 20 files per call; saved after each batch. A file that cannot be read gets an empty hash.
3. **Group**: every non-empty hash held by two items or more is a group of kind `exact`, rebuilt after each scan; the item to keep is marked ([best pick](#best-pick)).

**When**: after each index sync (launch, return to the foreground), by `DuplicateScan`. A changed file (modification date or size) loses its hash at the next sync and is hashed again.

**Display**: groups are stored for the whole library. A grid shows only the members among its items, a group needs at least two, trashed items are left out, and the best item is picked again among those shown.

### Performance

- Only size collisions are read. Each file is read once; its hash is kept until the file changes, so later scans read only new candidates.
- Hashing runs on its own native thread; the 1 MB buffer is reused.
- Rebuilding the groups is one SQL grouping on `content_hash` plus inserts.

## Bursts

Shots of one burst sequence: the camera saves each shot as a file with a shared part in its name ([burst.dart](../lib/analysis/burst.dart)).

| Camera | File names | Burst id from |
| --- | --- | --- |
| Samsung | `20240315_142233_001.jpg`, `20240315_142233_002.jpg`, … | `20240315_142233` |
| Google Camera | `IMG_20240315_142233_BURST001.jpg`, `IMG_20240315_142233_BURST002_COVER.jpg` | `IMG_20240315_142233` |
| Older Google Camera | `00000IMG_00000_BURST20190101123456789_COVER.jpg` | `20190101123456789` |

- The folder is part of the id, so shots are grouped only with those saved next to them.
- The id is worked out when the item is indexed (`assets.burst_id`), from its name: no file is read.
- After each scan, every burst id held by two items or more is a group of kind `burst`, unless its items are already exactly one exact group (a burst saved twice).
- Bursts have their own **Bursts** chip and section on the duplicates screen (they were listed with exact duplicates under *Certain duplicates* until 2026-10-27); the best shot is chosen by the [best pick](#best-pick): the sharpest once measured, otherwise the largest file, which usually holds the most detail.

**Not used**: grouping photos taken less than a second apart without a burst name. Two different photos taken quickly are not certain duplicates; close-in-time look-alikes are found by similar photos (M4), which compare the images. MediaStore has no burst column, and Samsung keeps its burst metadata in a proprietary format.

## Screenshots

Photos taken of the screen, offered for cleaning once old ([features/cleanup.md](features/cleanup.md)). `isScreenshot` ([screenshot.dart](../lib/analysis/screenshot.dart)) applies the brief's three signs, the first that matches:

| Sign | Example |
| --- | --- |
| A folder named `Screenshots` in the path | `DCIM/Screenshots/` (Samsung), `Pictures/Screenshots/` (Pixel) |
| A file name starting with "Screenshot" (also "Screen shot", "screen_shot") | `Screenshot_20240315-142233_Chrome.jpg` saved elsewhere |
| A PNG exactly the size of the device's display, in either orientation | A screenshot saved by an app in its own folder |

- Photos only: screen recordings are videos.
- Worked out when the item is indexed (index rules version 3), from its path, name, type and size: no file is read. The display size comes from Flutter (`screenSizeProvider`), in physical pixels.
- The size rule needs a PNG: a JPEG at the screen's size is more often a wallpaper or a received picture. A folder named like `Screenshots backup` does not count: only a folder named exactly `Screenshots`, in any case.

## Similar photos

Photos that look alike without being identical files: the same photo resized or recompressed by a messaging app, an edited copy, shots taken a few seconds apart ([ADR 0018](decisions/0018-perceptual-hashes-from-thumbnails.md), [ADR 0019](decisions/0019-similar-photo-search.md)). Photos only; videos are not compared yet.

### Hashes

Each photo gets two 64-bit perceptual hashes, computed from a grayscale thumbnail of at most 256 × 256 pixels (128 until M5) rendered by MediaStore's thumbnail cache, the same one the [quality](#blurry-and-dark-photos) is measured on. The original file is never decoded.

| Hash | How | Robust to | Used for |
| --- | --- | --- | --- |
| pHash | Area-average resize to 32 × 32, 2D DCT, the 8 × 8 lowest frequencies (DC row and column left out), bit = above their median | Resizing, recompression, brightness, small edits | The similarity rules |
| dHash | Area-average resize to 9 × 8, bit = darker than the right neighbour | Resizing, brightness | The confidence score |

The **distance** between two hashes is the number of differing bits (Hamming distance), from 0 (same picture) to 64; unrelated photos are around 32 apart. Measured on the synthetic test set ([photo_set.dart](../test/analysis/photo_set.dart)):

| Change | pHash distance |
| --- | --- |
| JPEG quality 30, resized to 40 % or 200 % | 0 |
| Brightness +25 | 2 |
| Subject moved by 5 / 15 / 30 pixels (out of 480) | 4 / 12 / 20 |
| 3 % / 6 % cropped from each side | 8 / 16 |
| Unrelated scenes | 20 or more (about 32 on average) |

### Rules

Two photos are similar when their pHash distance is

1. at most the **strict** threshold and their aspect ratios differ by at most 2 %, whatever their dates; or
2. at most the **loose** threshold and they were taken at most the **time window** apart (capture dates, see [capture date](#capture-date)).

Similar pairs are joined into groups transitively (union-find). Pairs are never joined when the user marked them **Not duplicates** (`ignored_pairs`), or when both photos are already in one exact or burst group: certain duplicates stay in their own section, but a copy can still join a look-alike in a similar group.

### Sensitivity

Chosen in Settings ([settings.md](features/settings.md)); changing it regroups from the stored hashes, without reading any thumbnail.

| Preset | Strict | Loose | Time window |
| --- | --- | --- | --- |
| Low | 4 | 10 | 5 s |
| **Medium** (default, the brief's values) | 6 | 12 | 10 s |
| High | 8 | 14 | 30 s |
| Advanced mode | 0–10 | 0–20 | 0–60 s |

**Why these bounds**: at a strict distance of 12, unrelated photos start to match (random hashes gave 90 false groups among 30,000), so the advanced mode stops at 10. The loose rule is protected by the time window, so it goes further.

### Confidence

Each member of a group is stored with the confidence (0 to 1) of its closest match: `1 − (pHash distance + dHash distance) / 64`, plus 0.1 if both photos come from the same camera model and 0.1 if they were taken within 100 m, capped at 1. Camera model and location are not read yet (info panel, M6; map, M7), so the bonuses do not apply for now. The score is stored in `duplicate_members.score`; the screen does not show it yet.

### Not duplicates

A **Not duplicates** button under each similar group stores every pair of its shown photos in `ignored_pairs`. The group disappears at once and the photos are never grouped together again, even after **Analyze the library again**. A photo of the group can still be grouped with other photos.

### Performance

Measured on the development laptop (Intel i5-7200U, AOT-compiled, CPU sometimes throttled to 600 MHz), 30,000 photos:

| Step | Time |
| --- | --- |
| Both hashes of one photo, in Dart | 1–2.5 ms |
| Grouping at Medium / High | 0.6–1.1 s / 1.4–2.6 s |
| Grouping at strict 12 (above the advanced mode's limit) | 4.6–9 s |

On the phone, rendering the thumbnail (MediaStore) costs more than hashing it; the first analysis of a large library takes minutes, in the background, saved every 16 photos (about a second of work), and paused while the viewer is open so the photo being opened is not delayed. Four native threads render thumbnails at once. Measured on the Galaxy A54 on 2026-10-27, release build: about 760 photos a minute with two threads, 860 with four (so about 25 minutes for the first analysis of 20,000 photos), the grid staying fluid; MediaStore's thumbnail rendering is the limit, not the app. Reading the thumbnail embedded in camera JPEGs would be much faster but may hash differently from MediaStore's rendering (and WhatsApp copies have none); not done. Similar photos are regrouped every 60 batches (960 photos), newest first, so the first groups show long before the end; the screens show "Analyzing: N of M items". A photo that fails to render is left without hashes; a batch that fails as a whole (an unexpected native error) is saved without hashes too, so the scan goes on instead of stopping on it at every launch. Later scans hash only new or changed photos.

**Search**: strict pairs are found by multi-index hashing (four 16-bit blocks of the pHash; two hashes within *r* bits share a block within ⌊r / 4⌋ bits), loose pairs by walking the photos in date order. The brief asked for a BK-tree; on pHashes it was slower than comparing every pair, see [ADR 0019](decisions/0019-similar-photo-search.md).

## Blurry and dark photos

Photos out of focus, shaken, or too dark to show anything (a pocket shot, a covered lens), offered in the *Blurry photos* list ([features/cleanup.md](features/cleanup.md), [ADR 0020](decisions/0020-blur-and-brightness-with-the-hashes.md)).

| Measure | How | Stored in | Offered below |
| --- | --- | --- | --- |
| Sharpness | Variance of the 4-neighbour Laplacian over the inner pixels of the 256-pixel grayscale thumbnail | `blur_score` | 30 |
| Brightness | Mean of the thumbnail's pixels, 0 to 255 | `brightness` | 20 |

- Measured in the same isolate call as the perceptual hashes (`analyzePhoto`), so no photo is read twice; a photo without a readable thumbnail is not measured and never offered.
- Screenshots are left out: flat backgrounds would look blurry.
- **Thresholds**: a thumbnail is much sharper than its full-size photo, so the usual thresholds (around 100 at full size) do not apply. On the synthetic test photos ([photo_set.dart](../test/analysis/photo_set.dart)), sharp scenes score 54 to 250, recompressed ones included, and the same scenes blurred by 0.6 % of their width 7 to 19; 30 sits between. To check on real photos: a flat scene (sky, fog, a wall) can score low without being blurry.
- Sharpness also refines the [best pick](#best-pick).

## Best pick

`pickBest` ([best_picker.dart](../lib/analysis/best_picker.dart)) chooses the item to keep in a group, by the brief's order:

| Order | Rule | Why |
| --- | --- | --- |
| 1 | A favorite | The user already chose it. |
| 2 | Highest resolution | More detail. |
| 3 | Sharpest, when known for both | Burst shots and close shots have the same resolution: the one in focus is kept. Measured since M5 ([blurry and dark photos](#blurry-and-dark-photos)). |
| 4 | Largest file | Less compression. |
| 5 | Oldest capture date | Most likely the original. |
| 6 | Smallest id | Usually the first copy on the device; makes the choice stable. |

For exact duplicates, rules 2 to 4 are equal by definition, so the choice is the favorite, then the oldest, then the first copy.

## Tests

- [capture_date_test.dart](../test/analysis/capture_date_test.dart): file name patterns, rejected names, date-only names, resolution order.
- [media_index_test.dart](../test/core/media/media_index_test.dart): dates resolved during a sync, rules version, sorting by corrected or platform date.
- [android_media_source_test.dart](../test/platform/android_media_source_test.dart): when `DATE_TAKEN` counts as metadata.
- [best_picker_test.dart](../test/analysis/best_picker_test.dart): every rule of the best pick, in order.
- [burst_test.dart](../test/analysis/burst_test.dart): burst names of each camera, different bursts and folders, ordinary names.
- [duplicates_test.dart](../test/core/media/duplicates_test.dart): only size collisions hashed, groups, no re-read on a second scan, filter by folder, trash and undo, changed file hashed again, favorite kept, burst groups, a burst saved twice.
- [image_quality_test.dart](../test/analysis/image_quality_test.dart): sharp, recompressed, blurred, dark and flat images.
- [perceptual_hash_test.dart](../test/analysis/perceptual_hash_test.dart): Hamming distance, area resize, the same photo recompressed, resized, brightened, cropped; false positive regression on 40 unrelated scenes.
- [similarity_test.dart](../test/analysis/similarity_test.dart): multi-index search against brute force, union-find, strict and loose rules, aspect ratio, chains, ignored pairs, certain groups, presets, confidence, a mixed test photo set.
- [similar_photos_test.dart](../test/core/media/similar_photos_test.dart): scan through the media source: groups, photos only, hashes kept, sharpness and brightness measured, the sharper look-alike kept, Not duplicates kept by Analyze again, changed file, new thresholds without re-reading, exact copies, folder filter.
- [photo_set.dart](../test/analysis/photo_set.dart): the synthetic test photos (seeded scenes, recompressed, resized, brightened, cropped, moved subject), made in memory.
