# ADR 0008 — Five-tab navigation and own visual identity

The navigation and the look of the app deviate from the brief at the product owner's request. This ADR records what changed and where the affected features now live.

Last updated: 2026-11-04 — Visual refresh

- **Status**: Accepted
- **Date**: 2026-10-25
- **Supersedes**: the "Navigation" and "User interface" sections of the brief ([prompt.md](../../prompt.md)), and the `dynamic_color` choice in [ADR 0001](0001-flutter-and-package-stack.md)

## Context

After seeing M0 on a phone, the product owner found the design too close to stock Google apps, and asked for:

- a more distinctive look, without clutter;
- a much smaller bottom bar, icons only;
- tabs **Photos, Videos, Albums, Settings** instead of Photos · Folders · Clean;
- a **Stats** tab showing how much space cleaning could free.

The brief had three tabs at most, Settings and Trash in a top menu, and Material You dynamic colors.

## Decision

| Topic | Brief | Now |
| --- | --- | --- |
| Tabs | Photos · Folders · Clean | Photos · Videos · Albums · Stats · Settings |
| Bottom bar | Material `NavigationBar` with labels | Floating 56 dp pill, icons only ([design.md](../design.md#navigation-bar)) |
| Colors | Material You, from the wallpaper | Fixed ink/paper palette with one lime accent |
| Typeface | System (Roboto) | Manrope, bundled |
| Settings | Top menu | Tab |
| Trash | Top menu | Virtual album at the top of Albums (with Favorites) |
| Cleanup tools (duplicates, swipe, blurry, screenshots, large videos) | Clean tab | Reached from the Stats tab: each category opens its tool |
| Storage dashboard | Top of the Clean tab | Stats tab |
| Banner ad | Bottom of the Folders tab | Bottom of the **Albums** tab, above the navigation bar |
| Native ad card | Clean tab | **Stats** tab, between the category cards |

The "Duplicates" virtual tile stays at the top of every album grid, as in the brief.

## Consequences

- `dynamic_color` is removed from the dependencies.
- Five tabs exceed Material's guidance of three to five with labels; icon-only tabs rely on tooltips and screen reader labels. A widget test checks the 48 dp touch targets.
- Separate Photos and Videos tabs mean "All media" mixing both lives in Albums ("All photos" album in the brief, to be renamed "All media" in M1).
- The two ad placements keep the same rule (only two, nothing else), but in different tabs. [AGENTS.md](../../AGENTS.md) is updated.
- M1 builds the Photos, Videos and Albums tabs; M5 fills the Stats tab with real values and links to the cleanup tools.

## Amendment (M2): Camera instead of Photos

At the product owner's request, the first tab shows **only the photos of the device camera** (MediaStore `RELATIVE_PATH` starting with `DCIM/Camera/`) instead of every photo. Screenshots, received and downloaded images stay out of it; every item remains reachable through **Albums → All media**. The tab is named "Camera" ("Appareil photo") with a camera icon so its name matches its content. The Videos tab still lists every video.

## Amendment (2026-11-04): colors and typeface

[ADR 0028](0028-warm-eclat-identity.md) replaces the palette and the title typeface of this decision. Its navigation stands.
