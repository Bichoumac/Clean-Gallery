# ADR 0015 — Persistent media index in Drift

Why every list now reads the app's own database instead of MediaStore, and how the database is kept in sync.

Last updated: 2026-10-26 — Milestone M3

- **Status**: Accepted
- **Date**: 2026-10-26

## Context

Until M2, every list (timelines, albums, counts, covers) queried MediaStore through `photo_manager` when it was opened, so each launch started with skeletons while MediaStore was read again. The product owner asked for caching so that lists show at once. The brief also asks for "incremental indexing" in M3: the analysis engine (dates, hashes, duplicates) needs a row per item in the `assets` table anyway.

## Decision

- **The `assets` table is the media index.** Every list reads it: timelines, album pages, the Albums tab, counts and covers ([media_index_repository.dart](../../lib/core/database/media_index_repository.dart)). At launch, lists come from SQLite and show in the first frames.
- **Sync in two steps** ([media_index.dart](../../lib/core/media/media_index.dart)):
  1. `snapshot`: one MediaStore query returns the id and `GENERATION_MODIFIED` of every photo and video, newest first (two `long` arrays, a few hundred KB for 30,000 items).
  2. The snapshot is compared with the stored revisions: new and changed ids are described (`describe`, full metadata, 1,000 ids per call), missing ones are removed.
- **`GENERATION_MODIFIED`** (Android 11+, our minimum) changes on every update of a MediaStore row, favorite flag included, unlike `DATE_MODIFIED`. Its counter is per database, so the MediaStore version (`MediaStore.getVersion`) is stored too: when it changes (database rebuilt, ids possibly reassigned), every item is described again and its analysis reset.
- **When a sync runs**: at launch, when the app returns to the foreground, and on pull-to-refresh. Concurrent calls merge into one more pass.
- **Lists reload in place.** A sync increments a revision; each open list queries the index again in the background and replaces its content without a loading state, so the scroll position is kept. During a long sync (first launch), lists refresh after the first 1,000 items, then at most once a second.
- **Analysis results survive syncs.** Upserts update only metadata columns; `analysis_version` is reset only when the file changed (modification date or size).
- **First launch**: until one sync completes (`media_index_version` setting), an empty list shows the skeleton instead of the empty state.
- **`photo_manager` stays** for full-resolution files and video URIs only; listing, counts and file sizes no longer use it. The native `albumSummaries` and `mediaSizes` methods are removed.

## Alternatives considered

- **Keep MediaStore queries and cache their results in memory**: no gain at launch, which is what the product owner asked for.
- **`ContentObserver` on MediaStore**: tells that something changed, not what; a sync is still needed. Not worth it while the app syncs at every return to the foreground. Can be added later to pick up photos taken while the app is open.
- **`MediaStore.getGeneration` per volume and a `generation_modified > n` query**: fewer rows read, but generations are per volume and deletions are not reported, so the full id list is needed anyway. The snapshot covers both cases in one query.
- **Drift streams (`watch`) for lists**: they re-run on every write to `assets`, including the analysis engine's writes coming in M3 and M4. An explicit revision lets syncs decide when lists reload.

## Consequences

- Launch shows the last known library at once; changes made outside the app appear a moment later.
- The first launch reads the whole library once; the timeline fills from the newest items.
- With limited access (Android 14+), the index holds only the shared items. Items in the app trash are kept even if they are no longer shared, so they are not forgotten.
- Photos taken while the app stays in the foreground appear after pull-to-refresh or the next return to the app.
- Sorting and filtering happen in SQLite with the same rules as before ([ADR 0012](0012-sort-and-date-filter.md)); indexes on `taken_at` and `bucket_id` keep them fast.
