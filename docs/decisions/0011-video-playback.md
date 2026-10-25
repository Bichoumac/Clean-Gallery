# ADR 0011 — Video playback with `video_player` and own controls

Which video package the viewer uses, and why its controls are custom.

Last updated: 2026-10-25 — Milestone M1

- **Status**: Accepted
- **Date**: 2026-10-25

## Context

The brief suggests `media_kit`, or `video_player` with `chewie`. Needed: play/pause, progress bar, sound, full screen, rotation, for the videos of the device.

| Package | Version | Last published | Notes |
| --- | --- | --- | --- |
| `video_player` | 2.14.1 | 2026-10-02 | Official Flutter plugin; ExoPlayer on Android; plays `content://` URIs directly. |
| `chewie` | 1.17.4 | 2026-10-22 | Maintained; Material and Cupertino control styles. |
| `media_kit` | 1.2.6 | 2025-12-13 | Bundles libmpv: many formats, but adds tens of megabytes per CPU architecture. |

## Decision

- **`video_player`**, opened with `VideoPlayerController.contentUri`, so videos stream from MediaStore without copying files.
- **Own controls** ([video_page.dart](../../lib/features/viewer/video_page.dart)): lime play button, progress slider, mute and rotate, matching [design.md](../design.md) instead of `chewie`'s Material look.
- Only the current page plays; swiping away pauses it.

## Alternatives considered

- **`chewie`**: saves the controls code, but brings back the stock look the product owner rejected ([ADR 0008](0008-navigation-and-visual-identity.md)).
- **`media_kit`**: broader codec support than the phone's own decoders, at a large size cost, for videos the phone itself recorded or received.

## Consequences

- Playback relies on the device's decoders (ExoPlayer): a video the phone's own gallery cannot play will not play here either.
- Picture-in-picture and playback speed are not provided; not in the brief.
