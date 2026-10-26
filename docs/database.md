# Database

The app stores its index, analysis results, trash and settings in a local SQLite database managed by Drift. It runs on a background isolate so queries never block the UI. This file lists the schema, indexes and migration history.

Last updated: 2026-10-26 — Milestone M3

Source: [tables.dart](../lib/core/database/tables.dart), [app_database.dart](../lib/core/database/app_database.dart).

## Conventions

- Enum columns store the enum **name** as text. Renaming an enum value in [enums.dart](../lib/domain/enums.dart) is a schema change.
- Dates are stored by Drift as Unix timestamps (seconds).
- 64-bit hashes are stored as signed `INTEGER`.
- Foreign keys are enabled on every connection (`PRAGMA foreign_keys = ON`). Deleting an asset cascades to every table that references it.

## Tables

### `assets`

The media index: one row per photo or video, keyed by its MediaStore id. Every list of the app reads it; [MediaIndex](../lib/core/media/media_index.dart) keeps it in sync with MediaStore ([ADR 0015](decisions/0015-persistent-media-index.md), [library.md](features/library.md#media-index)). Queries live in [MediaIndexRepository](../lib/core/database/media_index_repository.dart). Analysis columns are filled incrementally by the engine; a sync updates only the metadata columns and resets `analysis_version` when the file changed (modification date or size).

| Column | Type | Null | Notes |
| --- | --- | --- | --- |
| `id` | INTEGER PK | no | MediaStore id |
| `folder` | TEXT | no | Album name (`BUCKET_DISPLAY_NAME`) |
| `bucket_id` | TEXT | yes | Album id (`BUCKET_ID`); `null` until indexed |
| `relative_path` | TEXT | no | e.g. `DCIM/Camera/` |
| `file_name` | TEXT | no | |
| `mime_type` | TEXT | no | |
| `kind` | TEXT | no | `photo` / `video` |
| `size_bytes` | INTEGER | no | |
| `width`, `height` | INTEGER | no | Pixels |
| `duration_ms` | INTEGER | yes | Videos only |
| `modified_at` | DATETIME | no | File modification date |
| `taken_at` | DATETIME | no | MediaStore capture date: `DATE_TAKEN`, or `DATE_ADDED` when unset. Timelines sort and group by it |
| `media_revision` | INTEGER | yes | MediaStore `GENERATION_MODIFIED` when indexed; `null` forces a refresh |
| `capture_at` | DATETIME | yes | Resolved capture date (metadata, file name, then file date), written by the index sync ([analysis-engine.md](analysis-engine.md#capture-date)). Timelines use `COALESCE(capture_at, taken_at)` when corrected dates are on |
| `capture_source` | TEXT | yes | `exif` / `filename` / `file` |
| `content_hash` | TEXT | yes | SHA-256 of the content (hex), only for items whose size is shared; `''` when the file could not be read; reset when the file changes ([ADR 0017](decisions/0017-exact-duplicates-sha256.md)) |
| `d_hash`, `p_hash` | INTEGER | yes | 64-bit perceptual hashes |
| `blur_score` | REAL | yes | Laplacian variance; higher is sharper |
| `burst_id` | TEXT | yes | |
| `is_screenshot` | BOOLEAN | no | Default `false` |
| `is_favorite` | BOOLEAN | no | Default `false`; cached copy of MediaStore `IS_FAVORITE` |
| `latitude`, `longitude` | REAL | yes | From EXIF GPS |
| `camera_model` | TEXT | yes | From EXIF |
| `analysis_version` | INTEGER | no | Default `0`; see below |

`is_favorite` is not in the original brief. The engine's best-shot rule ranks favorites first, so the flag must be readable inside the analysis isolate, without calling MediaStore.

### `duplicate_groups`

Used since M3 by [DuplicateRepository](../lib/core/database/duplicate_repository.dart): groups of kind `exact` are deleted and rebuilt after each duplicate scan; `duplicate_members.is_suggested_keep` marks the best item of the whole group ([analysis-engine.md](analysis-engine.md#exact-duplicates)).

| Column | Type | Notes |
| --- | --- | --- |
| `id` | INTEGER PK autoincrement | |
| `kind` | TEXT | `exact` / `burst` / `similar` |
| `computed_at` | DATETIME | |

### `duplicate_members`

| Column | Type | Notes |
| --- | --- | --- |
| `group_id` | INTEGER FK → `duplicate_groups.id` | Cascade delete |
| `asset_id` | INTEGER FK → `assets.id` | Cascade delete |
| `is_suggested_keep` | BOOLEAN | The "Best" badge |
| `score` | REAL | Confidence, 0 to 1 |

Primary key: (`group_id`, `asset_id`).

### `ignored_pairs`

Pairs the user marked as "not duplicates". Always stored with `asset_a < asset_b`.

| Column | Type |
| --- | --- |
| `asset_a` | INTEGER FK → `assets.id` |
| `asset_b` | INTEGER FK → `assets.id` |

Primary key: (`asset_a`, `asset_b`).

### `trash_entries`

Used since M2 by [TrashRepository](../lib/core/database/trash_repository.dart) ([trash.md](features/trash.md)). The trashed item's `assets` row is normally already there (the index); if not, trashing inserts a minimal one with `INSERT OR IGNORE`, completed by the next sync. The trash screen reads items from `assets`, without querying MediaStore. Deleting an item for good deletes its asset row, which cascades to its trash entry; so does a sync that finds the item gone from the device (except with limited access, see [library.md](features/library.md#media-index)).

The brief calls this table `trash`. The Dart class is `TrashEntries` (table `trash_entries`) so that the plural table and singular row names read naturally (`TrashEntries` / `TrashRow`).

| Column | Type | Notes |
| --- | --- | --- |
| `asset_id` | INTEGER PK, FK → `assets.id` | |
| `trashed_at` | DATETIME | |
| `expires_at` | DATETIME | `trashed_at` + retention period |
| `original_folder` | TEXT | |

### `swipe_history`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | INTEGER PK autoincrement | |
| `session` | TEXT | Session id |
| `order` | INTEGER | Card position |
| `asset_id` | INTEGER FK → `assets.id` | |
| `action` | TEXT | `keep` / `trash` / `favorite` |

### `settings`

| Column | Type |
| --- | --- |
| `key` | TEXT PK |
| `value` | TEXT |

Known keys are constants in `SettingKeys` ([settings_repository.dart](../lib/core/database/settings_repository.dart)):

| Key | Type | Meaning |
| --- | --- | --- |
| `onboarding_completed` | bool | First-launch flow done |
| `trash_retention_days` | int, 1–90 | Days before a trashed item expires (default 30) |
| `remove_gps_on_share` | bool | Default of the share sheet's location switch (default `true`) |
| `default_columns` | int, 2–6 | Grid columns at launch (default 4) |
| `theme` | `system` / `light` / `dark` | Theme |
| `language` | `system` / `english` / `french` | Interface language |
| `last_purge_check` | ISO 8601 date | Day the expired trash was last offered for purging |
| `corrected_dates` | bool | Timelines use the resolved capture date (default `true`) |
| `capture_date_rules` | int | `captureDateRulesVersion` the indexed dates were resolved with; an older value makes the next sync resolve every date again |
| `media_index_version` | text | MediaStore version (`MediaStore.getVersion`) of the last complete index sync; unset before the first one |
| `view_sort:<filter>:<folder id>` | `<field>:<asc\|desc>` | Saved sort of one timeline, e.g. `view_sort:photos:` → `size:desc` |

They are read together by `SettingsRepository.loadAppSettings` before the first frame; invalid values fall back to the defaults ([settings.md](features/settings.md)).

## Indexes

| Index | Columns | Used by |
| --- | --- | --- |
| `assets_taken_at` | `assets(taken_at)` | Timelines in date order, date ranges, album covers |
| `assets_bucket_id` | `assets(bucket_id)` | Album pages, the Albums tab's grouping |

Other indexes (`assets(content_hash)`, `assets(capture_at)`, `trash_entries(expires_at)`) are added with the queries that need them, so each one is justified by a real query.

## `analysis_version`

Each asset records the version of the analysis algorithms that produced its analysis columns. When an algorithm changes, `analysisVersion` in [analysis_version.dart](../lib/analysis/analysis_version.dart) is bumped; the incremental indexer then re-analyses every asset with a lower version. This is a data refresh, not a schema migration.

## Migrations

Every schema change:

1. Bumps `schemaVersion` in `AppDatabase`.
2. Adds an `if (from < n)` step in `onUpgrade`.
3. Adds a row below.

| Version | Milestone | Change |
| --- | --- | --- |
| 1 | M0 | Initial schema. |
| 2 | M3 | Media index: `assets.bucket_id`, `taken_at`, `media_revision`; indexes `assets_taken_at`, `assets_bucket_id`. The table is rebuilt (`alterTable`): rows written by the M2 trash move their date from `capture_at` to `taken_at`, since `capture_at` is now reserved for the engine. |
