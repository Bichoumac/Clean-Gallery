# Analysis engine

Algorithms that work out facts about photos and videos on the device: capture dates now, then exact duplicates, bursts, similar photos and blur. This file lists each algorithm, its thresholds and their rationale, and performance notes.

Last updated: 2026-10-26 — Milestone M3

## Overview

| Step | Status | Where | Stored in |
| --- | --- | --- | --- |
| Capture date | Done (M3) | [capture_date.dart](../lib/analysis/capture_date.dart), applied by the media index sync | `assets.capture_at`, `capture_source` |
| Exact duplicates | M3 | — | `content_hash`, `duplicate_groups` |
| Bursts | M3 | — | `burst_id`, `duplicate_groups` |
| Similar photos | M4 | — | `d_hash`, `p_hash` |
| Blur | M5 | — | `blur_score` |

Code in `lib/analysis/` is pure Dart: no Flutter import, so it can run in an isolate and be tested without a device (a test enforces it).

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

During the media index sync, for each new or changed item, from the metadata the sync reads anyway: no file is opened ([ADR 0016](decisions/0016-capture-dates-at-index-time.md)). `captureDateRulesVersion` versions the rules; when it is bumped, the next sync describes every item again and resolves its date, keeping other analysis results. The version the index was built with is stored in the `capture_date_rules` setting.

### Performance

Resolving a date is a regular expression on the file name: well under a millisecond per item, inside a sync that already reads the item's metadata. A full re-resolution of 30,000 items costs one full sync (the same as the first launch).

## Tests

- [capture_date_test.dart](../test/analysis/capture_date_test.dart): file name patterns, rejected names, date-only names, resolution order.
- [media_index_test.dart](../test/core/media/media_index_test.dart): dates resolved during a sync, rules version, sorting by corrected or platform date.
- [android_media_source_test.dart](../test/platform/android_media_source_test.dart): when `DATE_TAKEN` counts as metadata.
