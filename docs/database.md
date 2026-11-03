# Database

The app stores its index, analysis results, trash, albums, saved slideshows, memories, rituals and settings in a local SQLite database managed by Drift. It runs on a background isolate so queries never block the UI. This file lists the schema, indexes and migration history.

Last updated: 2026-11-03 — Milestone M9

Source: [tables.dart](../lib/core/database/tables.dart), [app_database.dart](../lib/core/database/app_database.dart).

## Conventions

- Enum columns store the enum **name** as text. Renaming an enum value in [enums.dart](../lib/domain/enums.dart) is a schema change.
- Dates are stored by Drift as Unix timestamps (seconds).
- 64-bit hashes are stored as signed `INTEGER`.
- Foreign keys are enabled on every connection (`PRAGMA foreign_keys = ON`). Deleting an asset cascades to every table that references it.

## Tables

### `assets`

The media index: one row per photo or video, keyed by its MediaStore id. Every list of the app reads it; [MediaIndex](../lib/core/media/media_index.dart) keeps it in sync with MediaStore ([ADR 0015](decisions/0015-persistent-media-index.md), [library.md](features/library.md#media-index)). Queries live in [MediaIndexRepository](../lib/core/database/media_index_repository.dart). Analysis columns are filled incrementally by the engine; a sync updates only the metadata columns and resets `analysis_version`, `content_hash`, `d_hash` and `p_hash` when the file changed (modification date or size).

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
| `d_hash`, `p_hash` | INTEGER | yes | 64-bit perceptual hashes of photos, as signed integers, from a grayscale thumbnail; `null` until computed, or when the photo has no readable thumbnail ([ADR 0018](decisions/0018-perceptual-hashes-from-thumbnails.md)). Declared `int64()` until M3; `integer()` since M4 (same SQLite type, a Dart `int` instead of a `BigInt`, no migration) |
| `blur_score` | REAL | yes | Laplacian variance on the 256-pixel thumbnail; higher is sharper (M5) |
| `brightness` | REAL | yes | Mean brightness of the thumbnail, 0–255 (schema version 3, M5) |
| `contrast` | REAL | yes | Standard deviation of the thumbnail's pixels: tells hazy photos from blurry ones (schema version 4, M6, [ADR 0021](decisions/0021-hazy-photos-are-not-blurry.md)) |
| `burst_id` | TEXT | yes | `<relative path>\|<shared part of the name>` for a burst shot, from its file name at index time ([analysis-engine.md](analysis-engine.md#bursts)) |
| `is_screenshot` | BOOLEAN | no | Default `false`; set while indexing by `isScreenshot` (M5) |
| `is_favorite` | BOOLEAN | no | Default `false`; cached copy of MediaStore `IS_FAVORITE` |
| `latitude`, `longitude` | REAL | yes | From EXIF GPS, or the video's location; read by `LocationScan` for the map from schema version 5 ([features/map.md](features/map.md#reading-locations)); kept while the file does not change |
| `location_read` | BOOLEAN | no | Default `false`; whether the location was read, as `latitude` is `null` both before and without one (schema version 5, M6) |
| `camera_model` | TEXT | yes | From EXIF |
| `analysis_version` | INTEGER | no | Default `0`; see below |

`is_favorite` is not in the original brief. The engine's best-shot rule ranks favorites first, so the flag must be readable inside the analysis isolate, without calling MediaStore.

### `duplicate_groups`

Used since M3 by [DuplicateRepository](../lib/core/database/duplicate_repository.dart): groups of kind `exact` and `burst` are deleted and rebuilt after each duplicate scan, then groups of kind `similar` (M4); `duplicate_members.is_suggested_keep` marks the best item of the whole group ([analysis-engine.md](analysis-engine.md#exact-duplicates)). Trashed items stay in their groups; screens leave them out.

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
| `score` | REAL | Confidence, 0 to 1: `1` for certain duplicates; for similar photos, the confidence of the member's closest match ([analysis-engine.md](analysis-engine.md#confidence)) |

Primary key: (`group_id`, `asset_id`).

### `ignored_pairs`

Pairs the user marked as "not duplicates" (M4): every pair of a similar group's shown photos. Always stored with `asset_a < asset_b`. The similar photo search never joins them. Kept by *Analyze the library again*; removed with their asset (cascade).

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
| `session` | TEXT | Session id: the swipe source's key (`all`, `blurry`, `screenshots`, `month:2024-03`, `folder:<id>`) |
| `order` | INTEGER | Position of the decision in the session |
| `asset_id` | INTEGER FK → `assets.id` | Cascade: a deleted item leaves its session |
| `action` | TEXT | `keep` / `trash` / `favorite` |

Written by `SwipeRepository` since M5: one row per decision, the last row removed on *Undo*, every row of a session removed on *Start over* ([features/swipe.md](features/swipe.md)).

### `user_albums`

Albums created by the user (schema version 6, M8). Only lists: no file is moved, copied or deleted for an album ([ADR 0025](decisions/0025-user-albums-in-the-database.md), [features/user-albums.md](features/user-albums.md)).

| Column | Type | Notes |
| --- | --- | --- |
| `id` | INTEGER PK autoincrement | |
| `name` | TEXT | Trimmed; unique ignoring case, checked by the app |
| `cover_asset_id` | INTEGER, nullable | Item chosen as the cover; not a foreign key, ignored when the item left the album, the index or is trashed; `null`: the newest item |
| `created_at` | INTEGER (date) | Albums are listed newest first |

### `user_album_items`

| Column | Type | Notes |
| --- | --- | --- |
| `album_id` | INTEGER FK → `user_albums.id` | Cascade: deleting an album removes its list |
| `asset_id` | INTEGER | MediaStore id. **Not** a foreign key: items that leave the index without leaving the device (limited access, rebuilt index) stay in their albums; items deleted for good are removed by `UserAlbumRepository.forget` |
| `added_at` | INTEGER (date) | |

Primary key (`album_id`, `asset_id`): an item is once in an album, and can be in several albums.

### `slideshows`

Slideshows saved by the user (schema version 7, M9). Saved on the user's tap only; nothing is rendered or exported ([ADR 0026](decisions/0026-saved-slideshows-without-video.md), [features/slideshow.md](features/slideshow.md)).

| Column | Type | Notes |
| --- | --- | --- |
| `id` | INTEGER PK autoincrement | |
| `title` | TEXT | Trimmed |
| `options` | TEXT | JSON written by `SlideshowOptions.encode`: `seconds`, `transition`, `order`, `videos`, `skip`, `music` (`{type: none \| bundled \| device, id?, uri?, name?}`); invalid values read as the defaults |
| `created_at` | INTEGER (date) | Listed newest first |

### `slideshow_items`

| Column | Type | Notes |
| --- | --- | --- |
| `slideshow_id` | INTEGER FK → `slideshows.id` | Cascade: deleting a slideshow removes its list |
| `position` | INTEGER | Playing order from 0; gaps after `forget` are kept |
| `asset_id` | INTEGER | MediaStore id. **Not** a foreign key, as in `user_album_items`; removed by `SlideshowRepository.forget` when the item is deleted for good |

Primary key (`slideshow_id`, `position`).

### `memories`

Automatic memories met so far (schema version 7, M9), shown in the *Memories* list until dismissed ([features/memories.md](features/memories.md)). Only the period is stored; its photos are read again when it plays.

| Column | Type | Notes |
| --- | --- | --- |
| `key` | TEXT PK | `<kind>:<first day>`, e.g. `thisWeek:2025-11-03` |
| `kind` | TEXT | `onThisDay` / `thisWeek` |
| `years_ago` | INTEGER | 1 or more |
| `start`, `end` | INTEGER (date) | The period; `end` excluded |
| `photo_count` | INTEGER | Good photos when found |
| `found_at` | INTEGER (date) | Listed most recently found first |
| `dismissed` | BOOLEAN | ✕ on the card or in the list; found again, it stays dismissed |

### `rituals`

Recurring slideshows scheduled by the user (schema version 7, M9). Only notifications are scheduled for them ([ADR 0027](decisions/0027-notifications-without-background-work.md)).

| Column | Type | Notes |
| --- | --- | --- |
| `id` | INTEGER PK autoincrement | Notification ids derive from it |
| `content` | TEXT | `lastWeek` / `lastMonth` / `savedSlideshow` / `userAlbum` |
| `target_id` | INTEGER, nullable | Saved slideshow or user album; not a foreign key, a missing target is shown as such |
| `repeat` | TEXT | `weekly` / `monthly` |
| `day` | INTEGER | 1–7 (Monday to Sunday) or 1–28 |
| `minute` | INTEGER | Minutes past midnight, 0–1439 |
| `enabled` | BOOLEAN | Notifications scheduled |
| `created_at` | INTEGER (date) | Listed in that order |

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
| `index_rules` | int | `indexRulesVersion` the index was built with (capture dates, burst ids, screenshots); an older value makes the next sync apply the rules to every item again. Was `capture_date_rules` (version 1) before bursts |
| `similarity_sensitivity` | `low` / `medium` / `high` / `custom` | Similar photo preset (default `medium`); `custom` uses the three keys below |
| `similarity_strict` | int, 0–10 | Advanced mode: strict pHash distance (default 6) |
| `similarity_loose` | int, 0–20 | Advanced mode: loose pHash distance (default 12) |
| `similarity_window` | int, 0–60 | Advanced mode: time window in seconds (default 10) |
| `screenshot_age_days` | int, 1–3650 | Age from which screenshots are offered for cleaning (default 30) |
| `large_video_megabytes` | int, 1–100000 | Size from which videos are offered for cleaning (default 100) |
| `slideshow_options` | JSON | Default slideshow options, as in `slideshows.options` |
| `memories` | `off` / `weekly` / `monthly` | Memories (default `weekly`) |
| `memories_weekday` | int, 1–7 | Day of the weekly memories notification (default 7, Sunday) |
| `memories_month_day` | int, 1–28 | Day of the monthly one (default 1) |
| `memories_minute` | int, 0–1439 | Its time (default 1140, 7 pm) |
| `memories_notify` | bool | Memories notification on (default `false`) |
| `media_index_version` | text | MediaStore version (`MediaStore.getVersion`) of the last complete index sync; unset before the first one |
| `view_sort:<filter>:<folder id>[:user<album id>]` | `<field>:<asc\|desc>` | Saved sort of one timeline, e.g. `view_sort:photos:` → `size:desc`; a user album adds `:user<id>` |

They are read together by `SettingsRepository.loadAppSettings` before the first frame; invalid values fall back to the defaults ([settings.md](features/settings.md)).

## Indexes

| Index | Columns | Used by |
| --- | --- | --- |
| `assets_taken_at` | `assets(taken_at)` | Timelines in date order, date ranges, album covers |
| `assets_bucket_id` | `assets(bucket_id)` | Album pages, the Albums tab's grouping |
| `user_album_items_asset` | `user_album_items(asset_id)` | Albums holding given items (*Already in it*), removing items deleted for good |
| `slideshow_items_asset` | `slideshow_items(asset_id)` | Removing items deleted for good from saved slideshows |

Other indexes (`assets(content_hash)`, `assets(capture_at)`, `trash_entries(expires_at)`) are added with the queries that need them, so each one is justified by a real query.

## `analysis_version`

Each photo records the version of the image analysis that produced its analysis columns: `0` means not analysed (new, changed file, or after *Analyze the library again*); `1` (M4) means its perceptual hashes were computed, or that it has no readable thumbnail. When an algorithm changes, `analysisVersion` in [analysis_version.dart](../lib/analysis/analysis_version.dart) is bumped; the next scan then analyses every photo with a lower version. This is a data refresh, not a schema migration. Version 2 (M5) adds sharpness and brightness on 256-pixel thumbnails, version 3 (M6) the contrast; the schema 4 migration moves the version 2 photos that are sharp enough (or have no readable thumbnail) to version 3, so only photos below the blur threshold are read again. Videos stay at `0` for now. M4 adds no schema change: the columns and `ignored_pairs` existed since schema version 1.

## Migrations

Every schema change:

1. Bumps `schemaVersion` in `AppDatabase`.
2. Adds an `if (from < n)` step in `onUpgrade`.
3. Adds a row below.

| Version | Milestone | Change |
| --- | --- | --- |
| 1 | M0 | Initial schema. |
| 3 | M5 | `assets.brightness`. Upgrades from version 1 get it from the version 2 table rebuild, which uses today's columns. |
| 4 | M6 | `assets.contrast`; from version 3, version 2 photos at a sharpness of 30 or more move to analysis version 3. |
| 5 | M6 | `assets.location_read`, for the map: every item's location is read once after the update. |
| 6 | M8 | Tables `user_albums` and `user_album_items`, index `user_album_items_asset`. |
| 7 | M9 | Tables `slideshows`, `slideshow_items`, `memories` and `rituals`, index `slideshow_items_asset`. |
| 2 | M3 | Media index: `assets.bucket_id`, `taken_at`, `media_revision`; indexes `assets_taken_at`, `assets_bucket_id`. The table is rebuilt (`alterTable`): rows written by the M2 trash move their date from `capture_at` to `taken_at`, since `capture_at` is now reserved for the engine. |
