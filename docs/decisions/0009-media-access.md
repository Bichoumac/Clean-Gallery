# ADR 0009 — Media access with `photo_manager` and own image providers

How the app reads photos and videos, and why thumbnails do not use `photo_manager_image_provider`.

Last updated: 2026-10-26 — Milestone M3

- **Status**: Accepted
- **Date**: 2026-10-25

## Context

The brief recommends `photo_manager` behind a `MediaSource` interface. Grids must scroll smoothly with tens of thousands of items, and full-size originals must never be loaded in bulk.

Packages checked on pub.dev on 2026-10-25:

| Package | Version | Last published | Verdict |
| --- | --- | --- | --- |
| `photo_manager` | 3.12.0 | 2026-08-09 | Used: maintained, 160/160 points, MediaStore paging and custom SQL filters. |
| `photo_manager_image_provider` | 2.2.0 | 2024-10-08 | Not used: no release for two years. |

## Decision

- **`MediaSource`** ([media_source.dart](../../lib/platform/media_source.dart)) is the only way to reach media. `AndroidMediaSource` implements it with `photo_manager`.
- **Own `ImageProvider`s** ([media_image_providers.dart](../../lib/platform/android/media_image_providers.dart)):
  - `NativeThumbnailProvider`: grid thumbnails and viewer previews from MediaStore's thumbnail cache through the app's own `thumbnail` channel method, as raw pixels ([platform-android.md](../platform-android.md#native-channel-clean_galleryplatform)); keyed by id, modification date and size so Flutter's image cache reuses it.
  - `AssetFullImageProvider`: reads the file and decodes it at most 4,096 px on the longest side, only when zooming.
- **Permissions stay in `PermissionService`**: `photo_manager`'s own permission check is turned off (`setIgnorePermissionCheck(true)`), so there is a single place that asks.
- **Favorites** use a MediaStore SQL filter on `IS_FAVORITE` (Android 11+), so the Favorites album matches Google Photos and other galleries.
- **Chunked loading**: lists load 1,000 items per call; the first chunk is shown at once.
- **Shared media code in `lib/core/media/`**: the media list providers, thumbnail widget and formatting are used by both the library and the viewer, and features must not import each other ([architecture.md](../architecture.md#dependency-rules)).

### Amendment (M1, after the first device test)

The first version rendered thumbnails with `photo_manager`'s `thumbnailDataWithSize` (Glide, JPEG, first-in-first-out queue). It was too slow on a real library, especially after scrolling far. Thumbnails and previews now use the native loader; `photo_manager` is still used for listing, filtering, files and video URIs.

### Amendment (M3, media index)

Lists no longer query MediaStore through `photo_manager`: they read the media index in the database, filled by the app's own `mediaSnapshot` and `mediaDetails` channel methods ([ADR 0015](0015-persistent-media-index.md)). `photo_manager` is now used only for full-resolution files and video URIs. Chunked loading becomes two SQLite queries: the first 1,000 items, then the rest.

## Alternatives considered

- **`photo_manager_image_provider`**: about 100 lines of value, but unmaintained; writing the two providers is small and keeps cache keys under our control.
- **Loading all items at once**: simpler, but a 30,000-item library would show a spinner for seconds.

## Consequences

- `ImageProvider` is a Flutter type in a platform interface. This is fine: the rule forbidding Flutter applies to `domain/` and `analysis/` only. An iOS implementation would provide its own providers.
- Reading the library on every launch is acceptable for M1; from M3 the `assets` table caches it and tracks changes incrementally.
