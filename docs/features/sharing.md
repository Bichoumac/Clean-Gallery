# Sharing

Sharing photos and videos through the system share sheet, with the option to remove GPS location from photos.

Last updated: 2026-10-25 — Milestone M2

## Purpose

Send one or more items to any app. By default (a setting), photos are shared as temporary copies without GPS data, so the recipient cannot see where they were taken; the originals are never changed.

## User flows

1. **Share** from the viewer top bar or the selection bar.
2. A small sheet shows "Share N items" and the **Remove location** switch, on or off according to Settings. If videos are included and the switch is on, it warns that their location cannot be removed.
3. **Share** opens the system share sheet.

## How location is removed

| Item | Shared as |
| --- | --- |
| JPEG, PNG, WebP photo | Copy with every GPS tag removed (`ExifInterface`); other metadata kept |
| Other photos (HEIC…) | Copy re-encoded as JPEG at quality 95, without any metadata (`ImageDecoder` applies the orientation) |
| Video | The original, unchanged (no reliable way to rewrite MP4 location metadata on device) |
| Any item, switch off | The original, through its MediaStore URI |

Copies go to the app cache (`cache/share/`, emptied before each share) and are served by a `FileProvider` limited to that folder. Originals are shared by their MediaStore URI, so large videos are never copied ([ADR 0014](../decisions/0014-native-sharing.md)).

## Screens and widgets

| Widget | File |
| --- | --- |
| `shareWithOptions` and the share sheet | [media_actions.dart](../../lib/core/media/media_actions.dart) |
| Native share | [MediaActions.kt](../../android/app/src/main/kotlin/com/bichoumac/clean_gallery/MediaActions.kt) |

## State and data

- Default of the switch: `removeGpsOnShare` setting ([settings.md](settings.md)).
- `PlatformBridge.share` → native `share` ([platform-android.md](../platform-android.md#native-channel-clean_galleryplatform)).

## Edge cases and error handling

- **Copy or re-encode fails**: "Sharing failed." and nothing is sent.
- **Mixed photos and videos**: shared together with type `*/*`.

## Tests

- [selection_test.dart](../../test/features/library/selection_test.dart): the share sheet opens with location removal on by default and sends one request.
- GPS removal itself is native and is checked on a device ([testing.md](../testing.md#m2--to-verify-on-a-device)).

## Known limitations / future work

- Video location is not removed (warned in the sheet).
- HEIC copies lose their other metadata (date, camera) as well.
