# ADR 0028 — Warm "Éclat Soleil" visual identity

The product owner replaced the lime identity with a warmer, more modern one and chose a logo. This ADR records the choice and the alternatives; values are in [design.md](../design.md), the work in [visual-refresh.md](../visual-refresh.md).

Last updated: 2026-11-04 — Visual refresh

- **Status**: Accepted, built
- **Date**: 2026-11-04
- **Supersedes**: the colors and typeface of [ADR 0008](0008-navigation-and-visual-identity.md); its navigation stands

## Context

The app has no launcher icon of its own: it still shows Flutter's. Lime on ink was distinctive but cold. The product owner set two constraints:

- the logo is rounded, with eight axes: an octagram, a rosace of eight petals or a mandala, in the spirit of the system gallery apps;
- a gallery's best art direction is the one you forget: neutral around the photos, one accent, character only where there are no photos.

Four directions and six logos were drawn. The product owner picked **Éclat**, then asked for warmer colors and a more modern design, and approved the warm version on 2026-11-04.

## Decision

| Topic | Before | Now |
| --- | --- | --- |
| Accent | Lime `#CFF25B` | Sun yellow `#FFCB47` |
| Dark surfaces | Blue-tinted ink `#0F1012` | Warm ink `#14110C` |
| Light surfaces | Paper `#F7F6F3` | Cream `#FBF8F1` |
| Photo grids | Same surfaces as other pages | **Neutral**: `#0A0A0A` / `#FFFFFF` |
| Titles | Manrope | Bricolage Grotesque |
| Other text | Manrope | Manrope |
| Lists on Albums and Stats | Rows in cards | Mosaic of tiles |
| Navigation bar | 86 % opacity | 72 %, with a thin line |
| Viewer play button | Accent | White, translucent |
| Logo | None (Flutter's) | Plein soleil rosace |

The logo stands for the app's distinctive feature: seven similar photos and the one worth keeping.

## Alternatives considered

| Option | Why not |
| --- | --- |
| Abricot `#FF9E5E` as the accent | The warmest, but too close to the trash red: *Keep* and *Trash* would look alike in the sort mode. |
| Citron doré `#E8E24C` | Barely warmer than lime: it does not answer the request. |
| Warm neutrals in the grids too | Would tint how photos look, against the product owner's rule. |
| Red or coral accent | Red already means deleting. |
| Multicolored translucent petals on white | The look of another well-known photo app; it would pass for a copy. |
| Other directions (Chambre noire, Herbier, Prisme) | Not chosen by the product owner. |
| Other logos: "Un pétale" on ink, "Lever de soleil" | Less visible on a home screen; the second loses the single kept petal. |

## Consequences

- A second bundled font adds about 400 KB; the file stays offline, as the promise requires.
- The icon and launch screen leave M12: they come with the refresh.
- Feature documents say "accent" instead of naming a color, so they hold before and after the refresh.
- Widgets already read the color scheme; the few hard-coded values are listed in [visual-refresh.md](../visual-refresh.md#code-to-change).
- Pulling a photo down to return to the grid is a new gesture, not only a new look.
