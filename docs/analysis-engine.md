# Analysis engine

Algorithms that work out facts about photos and videos on the device: capture dates, exact duplicates and bursts now, then similar photos and blur. This file lists each algorithm, its thresholds and their rationale, and performance notes.

Last updated: 2026-10-26 — Milestone M3

## Overview

| Step | Status | Where | Stored in |
| --- | --- | --- | --- |
| Capture date | Done (M3) | [capture_date.dart](../lib/analysis/capture_date.dart), applied by the media index sync | `assets.capture_at`, `capture_source` |
| Exact duplicates | Done (M3) | [duplicates.dart](../lib/core/media/duplicates.dart), hashing in [MediaIndex.kt](../android/app/src/main/kotlin/com/bichoumac/clean_gallery/MediaIndex.kt) | `content_hash`, `duplicate_groups` |
| Bursts | Done (M3) | [burst.dart](../lib/analysis/burst.dart), applied by the media index sync; groups by `DuplicateScan` | `burst_id`, `duplicate_groups` |
| Similar photos | M4 | — | `d_hash`, `p_hash` |
| Blur | M5 | — | `blur_score` |

Code in `lib/analysis/` is pure Dart: no Flutter import, so it can run in an isolate and be tested without a device (a test enforces it).

**Where the work runs.** The brief asks for an engine in an isolate, incremental and resumable. In M3 the heavy parts already run off the UI thread: SQL (grouping, candidates) in Drift's background isolate, file hashing on a native thread. What runs on the UI isolate is per-item rule matching during a sync (two regular expressions on a file name), well under a millisecond per item. A Dart isolate becomes worth it with image analysis (perceptual hashes, blur) in M4 and M5. Results are saved as they go, so an interrupted sync or scan resumes; **Settings → Analyze the library again** forgets them all and starts over.

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

During the media index sync, for each new or changed item, from the metadata the sync reads anyway: no file is opened ([ADR 0016](decisions/0016-capture-dates-at-index-time.md)). `indexRulesVersion` ([index_rules.dart](../lib/analysis/index_rules.dart)) versions the rules applied at index time (capture dates and [burst ids](#bursts)); when it is bumped, the next sync describes every item again and applies them, keeping other analysis results. The version the index was built with is stored in the `index_rules` setting.

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
- Bursts are listed with exact duplicates under **Certain duplicates**; the best shot is chosen by the [best pick](#best-pick): until sharpness is measured (M5), the largest file, which usually holds the most detail.

**Not used**: grouping photos taken less than a second apart without a burst name. Two different photos taken quickly are not certain duplicates; close-in-time look-alikes are found by similar photos (M4), which compare the images. MediaStore has no burst column, and Samsung keeps its burst metadata in a proprietary format.

## Best pick

`pickBest` ([best_picker.dart](../lib/analysis/best_picker.dart)) chooses the item to keep in a group, by the brief's order:

| Order | Rule | Why |
| --- | --- | --- |
| 1 | A favorite | The user already chose it. |
| 2 | Highest resolution | More detail. |
| 3 | Sharpest, when known for both | Blur scores come in M5. |
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
