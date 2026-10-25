# ADR 0013 — Trash purge at launch and resume, without a background job

Why expired trash items are purged when the app is open instead of by a daily WorkManager task, as the brief asks.

Last updated: 2026-10-25 — Milestone M2

- **Status**: Accepted by the product owner on 2026-10-25 (purge at launch, no reminder notification)
- **Date**: 2026-10-25

## Context

The brief: "Purge on expiry: at app launch and through a daily WorkManager task. With 'Media management', delete directly."

On Android 11 and later, an app can delete another app's media (the camera's photos, received images…) only through `MediaStore.createDeleteRequest`, which returns a `PendingIntent` that must be launched from an activity. With "Media management", the request is approved without a dialog, but it must still be launched from the foreground: Android's documentation for `MANAGE_MEDIA` states that apps "must get the access by calling `createWriteRequest()`, `createDeleteRequest()`, or `createTrashRequest()`". A background task has no activity to launch it from.

## Decision

- Purge **once a day, at launch and when the app returns to the foreground** ([trash_purge.dart](../../lib/features/trash/trash_purge.dart)).
- With "Media management": delete the expired items without any prompt.
- Without it: one in-app question ("X items have expired, delete them?"), then one system confirmation for the whole batch. "Later" waits until the next day.
- No WorkManager dependency.

## Alternatives considered

- **WorkManager task that deletes**: not possible, as explained above.
- **WorkManager task that posts a notification** ("X items expired, tap to clean"): feasible, but needs the notification permission on Android 13+ and a notification channel, for little benefit over the check at the next launch.

## Consequences

- Expired items stay on the device until the user next opens the app. They remain hidden in the app meanwhile.
- The reminder notification variant was declined; it can still be added later without changing the purge itself.
