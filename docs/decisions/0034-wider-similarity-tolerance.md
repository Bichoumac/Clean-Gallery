# ADR 0034 — Wider similarity tolerance, through the time window

Why the similar photo presets widen mainly through the loose distance and the time window, not the strict distance.

Last updated: 2026-11-11 — Issue #19

- **Status**: Implemented, waiting for the product owner's check on the phone
- **Date**: 2026-11-11

## Context

Issue #19: no similar photos were found, even at **High**. High was strict 8, loose 14, window 30 s ([ADR 0019](0019-similar-photo-search.md)).

The app's pHash was measured in Python on public test photos (scikit-image's photos and a few others, none of the product owner's), each paired with a copy panned, zoomed or brightened:

| Change between two shots | pHash distance, median | Max |
| --- | --- | --- |
| Pan 2 % | 8 | 18 |
| Pan 4 % | 16 | 22 |
| Pan 7 % | 24 | 36 |
| Zoom 5 % | 8 | 20 |
| Zoom 10 % | 16 | 28 |
| Exposure +25 % | 2 | 6 |
| Unrelated photos (153 pairs) | 32 | min 22 |

The same scene reframed a little is about 16 bits apart. High accepted 14 for photos at most 30 s apart and 8 for any date, so two shots of a scene taken a minute apart were never grouped. The dHash was not better on real photos (pan 4 %: median 15, max 47).

## Decision

- **Presets**:

  | Preset | Strict | Loose | Time window |
  | --- | --- | --- | --- |
  | Low | 4 | 10 | 10 s |
  | Medium | 6 | 14 | 1 min |
  | High | 10 | 18 | 10 min |

- **Advanced mode**: loose up to 24, window up to 30 min on a slider of stops (5 s, 10 s, 30 s, 1, 2, 5, 10, 15, 30 min). Strict stays capped at 10.
- **Wording**: Settings call the presets a **tolerance threshold**, and the text under them changes with the preset picked.
- The hash itself is unchanged: no photo needs hashing again, and the new presets apply at the next grouping.

## Measured cost

30,000 photos with random hashes, AOT on the development laptop:

| Thresholds | Time | Groups of unrelated photos |
| --- | --- | --- |
| Old High (8 / 14 / 30 s) | 0.43 s | 2 |
| Medium (6 / 14 / 1 min) | 0.16 s | 0 |
| High (10 / 18 / 10 min) | 0.45 s | 46 (41 from the loose rule) |
| Loose 16, 10 min, alone | 0.12 s | 2 |
| Advanced maximum (10 / 24 / 30 min) | 0.45 s | 2,756 |

Random hashes are a pessimistic stand-in: real unrelated photos were never under 22 bits apart.

## Alternatives considered

- **Raise the strict distance**: it compares photos of any date, so unrelated photos start to match from 12, and the search slows down sharply ([ADR 0019](0019-similar-photo-search.md)).
- **Loose 16 at High**: almost no false group, but it misses half of the 4 % pans. High is meant to show more and be checked; Medium keeps the safe side.
- **Another hash** (pHash with the DC row and column, a larger DCT): a little more tolerant to framing, but every photo would need hashing again, for a small gain.

## Consequences

- High shows more groups, a few of them wrong; its description asks to check them before cleaning, and nothing is deleted without the user.
- Users of the advanced mode keep their values; a window saved in seconds snaps to the nearest stop on the slider.
