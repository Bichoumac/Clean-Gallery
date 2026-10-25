# ADR 0006 — Permission handling and `minSdk 30`

How media permissions are requested, how the optional "Media management" access works, and the constraints that come with `minSdk 30`.

Last updated: 2026-10-25 — Milestone M0

- **Status**: Accepted
- **Date**: 2026-10-25

## Context

The brief sets `minSdk 30` (Android 11), forbids `MANAGE_EXTERNAL_STORAGE`, and requires: media permissions per Android version, Android 14+ partial access, `ACCESS_MEDIA_LOCATION`, and the optional `MANAGE_MEDIA` special access with a full fallback when it is missing.

## Decision

- **Runtime permissions through `permission_handler`**, behind the `PermissionService` interface. It handles `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` on Android 13+ and `READ_EXTERNAL_STORAGE` on 11–12, and reports partial access as `limited`.
- **GPS metadata only after media access**: `ACCESS_MEDIA_LOCATION` is requested right after a granted or limited media request, and skipped on denial, since it is useless without media.
- **`MANAGE_MEDIA` through the Kotlin channel**: it is a special app access granted in system settings, not a runtime prompt, and no package exposes it. `MainActivity` checks it with `MediaStore.canManageMedia` and opens `ACTION_REQUEST_MANAGE_MEDIA`.
- **Without `MANAGE_MEDIA`**, deletes and favorites (from M2) use `MediaStore.createDeleteRequest` and `createFavoriteRequest`, batched so the user confirms once per action.
- **`minSdk 30`** guarantees scoped storage and the MediaStore request APIs used above, so no legacy storage code path is needed.

## Open point: Google Play policy for `MANAGE_MEDIA`

Google Play restricts some media-related permissions to apps whose core purpose needs them, and may ask for a declaration in the Play Console. A gallery and cleanup app is the intended use case for `MANAGE_MEDIA`, but this must be confirmed against the current policy before the first release. If it is refused, the app already works without it. Tracked in [progress.md](../progress.md) and the release checklist (M9).

## Consequences

- Android 14+ partial access depends on `permission_handler`'s `limited` status; it must be checked on a real Android 14 device.
- Every feature that deletes or favorites must handle both paths (direct write and system request).
