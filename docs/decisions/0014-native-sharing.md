# ADR 0014 — Sharing with native intents instead of `share_plus`

How items are shared, and how GPS location is removed from shared photos.

Last updated: 2026-10-25 — Milestone M2

- **Status**: Accepted
- **Date**: 2026-10-25

## Context

The brief recommends `share_plus` and asks for an option to remove GPS location from shared items through a temporary copy made with `ExifInterface` on the Kotlin side, the original staying untouched.

`share_plus` shares files by path. The items here live in MediaStore; sharing them through a file API would mean reading or copying originals (videos can weigh gigabytes), while the system share sheet accepts MediaStore content URIs directly.

## Decision

- **Native share** in [MediaActions.kt](../../android/app/src/main/kotlin/com/bichoumac/clean_gallery/MediaActions.kt): `ACTION_SEND` / `ACTION_SEND_MULTIPLE` with MediaStore URIs and `FLAG_GRANT_READ_URI_PERMISSION`. Nothing is copied when location is kept.
- **Location removal** on temporary copies in `cache/share/`, served by an `androidx.core` `FileProvider` restricted to that folder:
  - JPEG, PNG, WebP: every GPS tag cleared with `androidx.exifinterface` 1.4.2;
  - other photo formats (HEIC…), which `ExifInterface` cannot write: re-encoded as JPEG without metadata;
  - videos: shared as they are, with a warning in the share sheet.
- New Android dependencies: `androidx.exifinterface:exifinterface:1.4.2`, `androidx.core:core-ktx:1.19.1` (latest stable on 2026-10-25).

## Alternatives considered

- **`share_plus`**: simpler on the Dart side, but works with file paths, and the copies without GPS still need native code.
- **Strip GPS from HEIC in place**: not supported by `ExifInterface`; writing HEIF metadata would need a native HEIF library.

## Consequences

- No `share_plus` dependency.
- HEIC copies lose all their metadata, not only GPS (documented in [sharing.md](../features/sharing.md)).
- Behaviour is native and checked on a device.
