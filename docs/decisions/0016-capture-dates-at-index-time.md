# ADR 0016 — Capture dates resolved at index time, without reading files

How the corrected capture date is computed, and why the app does not read EXIF itself.

Last updated: 2026-10-26 — Milestone M3

- **Status**: Accepted; the product owner chose corrected dates in the timelines, with a setting to turn them off (2026-10-26)
- **Date**: 2026-10-26

## Context

The brief asks for a capture date resolved from EXIF, then the file name, then the file date (`DateSource`). Until now timelines used MediaStore's date: `DATE_TAKEN` when set, otherwise `DATE_ADDED`. Photos received through messaging apps usually have no EXIF, so they were dated on the day they arrived, not the day they were taken.

## Decision

- **No EXIF reading by the app.** MediaStore already fills `DATE_TAKEN` from EXIF `DateTimeOriginal` (and from the creation time of videos) when it scans a file. Reading EXIF ourselves would open every file: minutes for a large library, for the same value.
- **Resolve at index time** ([capture_date.dart](../../lib/analysis/capture_date.dart)): when the media index writes a new or changed item, it computes `capture_at` and `capture_source` from what it has just read: metadata date, file name, file date. Pure Dart, no extra I/O.
- **Keep both dates**: `taken_at` (platform) and `capture_at` (resolved). The **Corrected dates** setting (on by default) chooses which one timelines sort, filter, group and show; switching needs no sync.
- **Version the rules** (`captureDateRulesVersion`, setting `capture_date_rules`) so a rule change re-resolves every date at the next sync without resetting other analysis results.
- **Distrust a `DATE_TAKEN` equal to the file date** (within 2 seconds): some devices copy the file date into it, which would hide the date in the file name.

## Alternatives considered

- **Read EXIF with `ExifInterface` in the background**: exact source for every photo, but one file open per photo for little gain, since MediaStore did it already. Can be added later for one case MediaStore misses (time zone offsets), if needed.
- **Resolve in an analysis pass after indexing** (like hashes): a second write per item and dates that change after the list is shown. Resolving during the sync shows the right date from the first frame.
- **Replace the platform date**: no way back for the user; the product owner asked for the choice.

## Consequences

- Received photos move to the day they were taken as soon as they are indexed; for the existing index, at the first sync after the update (one full sync).
- `capture_source` tells where each date came from, for the info panel (M6) and future rules.
- Date rules live in one pure function with unit tests ([analysis-engine.md](../analysis-engine.md#capture-date)).
