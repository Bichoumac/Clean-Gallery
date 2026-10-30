# ADR 0021 — Hazy photos are not blurry: sharpness relative to contrast

How the engine tells a photo taken in mist, fog or at night from a photo out of focus.

Last updated: 2026-10-27 — Milestone M6

- **Status**: Accepted
- **Date**: 2026-10-27

## Context

[ADR 0020](0020-blur-and-brightness-with-the-hashes.md) offers a photo as blurry below a sharpness (variance of the Laplacian) of 30. On the product owner's phone, some **night photos with lights, hazy from mist and cold**, were listed as blurry: mist lowers the contrast of the whole photo, so every edge is fainter and the variance of the Laplacian drops, although the photo is in focus. ADR 0020 had kept this alternative for that case.

A temporary build (never committed) showed several measures in the info panel; the product owner read them on their photos. Really blurry photos have both a low sharpness and a low relative sharpness; hazy ones a low sharpness but a relative sharpness of 150 or more.

## Decision

- **Contrast** (standard deviation of the thumbnail's pixels) is measured with the sharpness and brightness, in the same pass, and stored in `assets.contrast` (schema version 4).
- **Relative sharpness** = sharpness × 1000 / contrast². Scaling a photo's contrast scales its Laplacian variance by the same square, so mist leaves it unchanged while blur lowers it ([image_quality.dart](../../lib/analysis/image_quality.dart)).
- **Blurry** = sharpness below 30 **and** relative sharpness below 150 (`isBlurry`). The dark rule (brightness below 20) is unchanged.
- **Analysis version 3**, without reading the whole library again: the contrast only matters below 30, so the schema 4 migration marks the version 2 photos at 30 or more (and those without a readable thumbnail) as version 3; only the photos below 30 are analysed again, a few minutes at most. Photos not measured yet are judged on sharpness alone.

## Alternatives considered

- **Lower the threshold of 30**: finds fewer hazy photos but misses real blur too; the two overlap in sharpness alone.
- **Exempt dark photos with bright points (lights)**: specific to night shots, would not cover fog in daylight.
- **A full analysis again**: about 25 minutes on 20,000 photos for a value only a few hundred photos need.

## Consequences

- Hazy photos in focus leave the *Blurry photos* list and lose the *Blurry* label in duplicate groups.
- A photo both hazy and out of focus is still found: blur lowers the relative sharpness (11 to 25 on the synthetic photos, against 180 to 400 for the same photos in focus).
- The threshold of 150 comes from a handful of the product owner's photos; it may need adjusting on more.
