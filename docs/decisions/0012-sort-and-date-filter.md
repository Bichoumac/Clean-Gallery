# ADR 0012 — Sorting and date filter in every timeline

Timelines can be sorted by several criteria and limited to a date range, a request from the product owner during M1. This ADR records where sorting and filtering happen and why.

Last updated: 2026-10-26 — Milestone M3

- **Status**: Accepted
- **Date**: 2026-10-25

## Context

The brief only has a date range as one of the combinable filters of the Search screen (M7). The product owner asked for sorting by different criteria and a date filter directly in the timelines, as an important feature.

Libraries can hold tens of thousands of items, loaded by chunks of 1,000 ([ADR 0009](0009-media-access.md)). Sorting or filtering in memory would require loading the whole library first, and file sizes are not part of `photo_manager`'s entities.

## Decision

- **Sort and date range are part of `MediaSelection`** ([album.dart](../../lib/domain/album.dart)): `MediaSort` (date, name, size, duration; ascending or descending) and `DateFilter` (start included, end excluded, local time). Equal selections share one loaded list, and the viewer swipes in the grid's order.
- **MediaStore does the work** ([android_media_source.dart](../../lib/platform/android/android_media_source.dart)): a custom SQL filter with the media type, favorites and date conditions, and the `ORDER BY`. Chunked loading keeps working whatever the order.
- **One capture date everywhere**: sorting and filtering use `CASE WHEN datetaken > 0 THEN datetaken / 1000 ELSE date_added END`, the same rule `photo_manager` uses for `createDateTime`, so headers, order and filter always agree.
- **Per-view state for the session**: `viewSelectionProvider(base)` keeps one choice per tab or album ([media_providers.dart](../../lib/core/media/media_providers.dart)).
- **Date headers only in date order**: other orders show a plain grid.
- **UI**: a "Sort and filter" button next to the title, a bottom sheet that applies changes immediately, and removable chips for the active choices ([library.md](../features/library.md#sorting-and-date-filter)).

### Amendment (M3, media index)

Sorting and filtering moved from MediaStore SQL to the same conditions in SQLite on the media index ([ADR 0015](0015-persistent-media-index.md), [media_index_repository.dart](../../lib/core/database/media_index_repository.dart)). The capture date rule is unchanged: it is computed once when an item is indexed and stored as `assets.taken_at`.

## Alternatives considered

- **Sorting in memory**: would need the whole library before showing anything, and file sizes from a separate query per item.
- **Waiting for the Search screen (M7)**: the product owner wants it in the timelines now. Search will reuse `DateFilter`.

## Consequences

- `photo_manager` drops its own media-type condition when a custom `where` is given; the type condition is always written by the app. This also fixed the Favorites album, which could have counted favorite audio files.
- Since Android 11, MediaStore validates SQL more strictly; the `CASE` and `LOWER` expressions must be checked on a device ([testing.md](../testing.md#m1--to-verify-on-a-device)).
- The choice is not saved across launches yet; saving it is part of the settings work in M2.
