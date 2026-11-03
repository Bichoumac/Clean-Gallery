# ADR 0026 — Slideshows played live, saved as lists

Why slideshows are drawn by the app as they play, and saved as a list of items with their options instead of a video file.

Last updated: 2026-11-03 — Milestone M9

- **Status**: Accepted (product owner's answers of 2026-11-01, Q6 to Q8)
- **Date**: 2026-11-03

## Context

The product owner asked for slideshows from an album, a selection or a period, with music, and automatic memories. Q8: slideshows are saved on the user's tap and play again at any time; sharing and casting to a TV come later and must stay possible.

A slideshow could be rendered once into a video (MP4) or drawn live by the app from the photos.

## Decision

- The player draws each item from the photos themselves: a screen-sized preview, a crossfade (`AnimatedSwitcher`) and, for *Slow zoom*, a scale and drift animated over the photo's time. Videos play muted through `video_player`, 10 s at most.
- **Saving** stores a row in `slideshows` (title, options as JSON: time per photo, transition, order, videos, skipping, music) and the items **in playing order** in `slideshow_items`. A saved slideshow replays that list with those options; items trashed or deleted since are skipped.
- The music is played by a platform `MediaPlayer` (`SlideshowMusic.kt`) in a loop, not mixed into anything.
- No new package: `video_player` is already there, and the music player, the file picker and keeping the screen on are a few lines on the existing channel.

## Alternatives considered

- **Rendering a video** (FFmpeg or `MediaCodec`): heavy (an FFmpeg build adds tens of MB), slow on the phone, a large file per slideshow, and a change of one photo means rendering again. It is still the way to *share* a slideshow later: the saved list and options hold everything a renderer needs.
- **Storing the source** (album, period) rather than its items: a saved slideshow would change as the album changes; the product owner asked for a slideshow that "plays again", so the items are frozen when saved.
- **`just_audio` / `audioplayers`** for the music: a dependency for one looping track; `MediaPlayer` reads both a picked document and a bundled asset.

## Consequences

- Nothing is written to the device's storage; deleting a saved slideshow or uninstalling the app leaves every photo in place.
- A saved slideshow cannot be opened by another app until sharing as a video is built.
- Casting can later send the same items one by one.
