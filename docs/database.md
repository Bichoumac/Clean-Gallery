# Database

The app stores its index, analysis results, trash and settings in a local SQLite database managed by Drift. It runs on a background isolate so queries never block the UI. This file lists the schema, indexes and migration history.

Last updated: 2026-10-25 — Milestone M0

Source: [tables.dart](../lib/core/database/tables.dart), [app_database.dart](../lib/core/database/app_database.dart).

## Conventions

- Enum columns store the enum **name** as text. Renaming an enum value in [enums.dart](../lib/domain/enums.dart) is a schema change.
- Dates are stored by Drift as Unix timestamps (seconds).
- 64-bit hashes are stored as signed `INTEGER`.
- Foreign keys are enabled on every connection (`PRAGMA foreign_keys = ON`). Deleting an asset cascades to every table that references it.

## Tables

### `assets`

One row per media item, keyed by its MediaStore id. Analysis columns are filled incrementally by the engine.

| Column | Type | Null | Notes |
| --- | --- | --- | --- |
| `id` | INTEGER PK | no | MediaStore id |
| `folder` | TEXT | no | Album name |
| `relative_path` | TEXT | no | e.g. `DCIM/Camera/` |
| `file_name` | TEXT | no | |
| `mime_type` | TEXT | no | |
| `kind` | TEXT | no | `photo` / `video` |
| `size_bytes` | INTEGER | no | |
| `width`, `height` | INTEGER | no | Pixels |
| `duration_ms` | INTEGER | yes | Videos only |
| `modified_at` | DATETIME | no | File modification date |
| `capture_at` | DATETIME | yes | Resolved capture date |
| `capture_source` | TEXT | yes | `exif` / `filename` / `file` |
| `content_hash` | TEXT | yes | xxHash of the content |
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

## Indexes

No secondary indexes yet. Indexes on `assets(folder)`, `assets(content_hash)`, `assets(capture_at)` and `trash_entries(expires_at)` are planned with the queries that need them (M1 to M3), so each one is justified by a real query.

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
