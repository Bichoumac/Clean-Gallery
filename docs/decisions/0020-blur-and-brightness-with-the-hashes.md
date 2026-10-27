# ADR 0020 — Blur and brightness measured with the hashes, on 256-pixel thumbnails

How the engine finds blurry and very dark photos, and why the thumbnails of the analysis grew from 128 to 256 pixels.

Last updated: 2026-10-27 — Milestone M5

- **Status**: Accepted
- **Date**: 2026-10-27

## Context

The brief asks for a **Blurry or failed photos** list ("low sharpness score, very dark photos"), sharpness as "variance of the Laplacian on the grayscale thumbnail", and sharpness in the best pick. The engine already reads one grayscale thumbnail per photo for the perceptual hashes ([ADR 0018](0018-perceptual-hashes-from-thumbnails.md)), at 128 pixels. On the product owner's 20,000 photos, that read takes about 25 minutes, limited by MediaStore's rendering, not by the app.

A 128-pixel thumbnail is a 30× reduction of a 12 MP photo: only strong blur survives it. Every photo had to be read again anyway to measure it.

## Decision

- **One pass**: the same grayscale thumbnail gives the perceptual hashes, the sharpness and the brightness (`analyzePhoto`, [photo_analysis.dart](../../lib/analysis/photo_analysis.dart)), in the same isolate call.
- **256 pixels** instead of 128 (`perceptualThumbnailSide`). MediaStore renders both sizes from the same cached thumbnail, so the cost on the phone barely changes; four times the bytes cross the channel (about 64 KB a photo). The hashes resize to 32 × 32 and 9 × 8 anyway, so similar groups stay the same or nearly.
- **Sharpness**: variance of the 4-neighbour Laplacian over the inner pixels ([image_quality.dart](../../lib/analysis/image_quality.dart)), stored in `assets.blur_score`. **Brightness**: mean of the pixels, in the new `assets.brightness` (schema version 3).
- **Offered for cleaning** below a sharpness of 30 or a brightness of 20 (of 255), screenshots left out. On the synthetic photos, sharp scenes score 54 to 250 and the same blurred by 0.6 % of their width 7 to 19.
- `analysisVersion` 2: every photo is analysed again once, in the background.
- Chosen by the product owner on 2026-10-27, against keeping 128 pixels for the same reading time.

## Alternatives considered

- **Keep 128 pixels**: same 25 minutes, but only strong blur would be found.
- **Measure on the full photo**: the brief's rule is "on the grayscale thumbnail"; decoding 20,000 originals would take hours and much memory.
- **A second pass for blur only**: reads every thumbnail twice.
- **Contrast-normalized sharpness** (Laplacian variance divided by the image's variance): fewer false positives on flat scenes (sky, wall), but blurry low-contrast photos would be missed. To consider if real photos show such false positives.

## Consequences

- One more full analysis on update (about 25 minutes for 20,000 photos), then only new photos.
- The thresholds come from synthetic photos and must be checked on real ones; a flat scene (sky, fog, a wall) can be taken for blurry.
- The best pick now prefers the sharper of two photos of the same resolution: burst shots and close shots.
