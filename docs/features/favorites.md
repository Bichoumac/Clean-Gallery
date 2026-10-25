# Favorites

Favorites shared with the system gallery: the heart in Clean Gallery is the same as in Google Photos or Samsung Gallery.

Last updated: 2026-10-25 — Milestone M2

## Purpose

Read and write MediaStore's `IS_FAVORITE` flag, so favorites follow the user across gallery apps. The Favorites album lists them; grids show a heart on each.

## User flows

1. **Viewer**: heart button in the top bar toggles the current item.
2. **Selection**: heart button in the selection bar. If every selected item is already a favorite, it removes them; otherwise it adds them all.
3. Android shows one confirmation for the whole batch, or none when the app has "Media management".
4. The heart switches **at once** (optimistic update through `favoriteOverridesProvider`); if the user declines or the request fails, it switches back and "Favorites were not changed." is shown. Only the Favorites album and album counts reload.

## Screens and widgets

| Widget | File |
| --- | --- |
| Heart in the viewer top bar | [viewer_screen.dart](../../lib/features/viewer/viewer_screen.dart) |
| Heart in the selection bar | [media_timeline_view.dart](../../lib/features/library/media_timeline_view.dart) |
| `toggleFavorite` | [media_actions.dart](../../lib/core/media/media_actions.dart) |
| Favorites album | [albums_screen.dart](../../lib/features/library/albums_screen.dart) |

## State and data

- `MediaActions.setFavorite` → `PlatformBridge.setFavorite` → native `setFavorite` (`MediaStore.createFavoriteRequest`), see [platform-android.md](../platform-android.md#native-channel-clean_galleryplatform).
- Reading: the `IS_FAVORITE` column in every MediaStore query; the Favorites album filters on it.
- After a change, no list reloads: the change is applied in memory by `visibleMediaListProvider`. The Favorites album list, counts and covers are refreshed.

## Edge cases and error handling

- **User declines**: nothing changes; a snackbar says so.
- **Another request already open** (`busy`): treated like a decline.
- **Mixed selection**: one tap makes all of them favorites.

## Tests

- [selection_test.dart](../../test/features/library/selection_test.dart): favoriting a selection sends one request with the selected ids; the heart switches without reloading lists; a declined request switches it back.
- [library_test.dart](../../test/features/library/library_test.dart): Favorites album count.

## Known limitations / future work

- Whether `createFavoriteRequest` skips the confirmation with "Media management" must be checked on a device; Android documents the bypass for write, trash and delete requests.
- BestPicker (M4) ranks favorites first when choosing which duplicate to keep.
