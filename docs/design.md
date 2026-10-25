# Design system

Visual identity of Clean Gallery: palette, typography, shapes and navigation. The goal is an app that feels distinct from stock Google apps while staying calm and uncluttered.

Last updated: 2026-10-25 — Milestone M1

Source: [app_theme.dart](../lib/core/theme/app_theme.dart), [compact_nav_bar.dart](../lib/core/router/compact_nav_bar.dart). Why this direction was chosen: [ADR 0008](decisions/0008-navigation-and-visual-identity.md).

## Principles

1. **One accent.** Lime is the only color that draws attention: the selected tab, the main button, the key number on a screen. Everything else is neutral.
2. **Content first.** Photos bring the color; the interface stays ink and paper around them.
3. **Big type, little chrome.** Large bold page titles replace app bars. No shadows; separation comes from surface tones and thin outlines.
4. **Soft geometry.** Large radii and pills everywhere, no sharp corners.

## Palette

The palette is fixed and does not follow the wallpaper (no Material You dynamic colors).

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `primaryContainer` | `#CFF25B` lime | `#CFF25B` lime | Selected tab, filled buttons, hero card |
| `onPrimaryContainer` | `#121316` ink | `#121316` ink | Text and icons on lime |
| `primary` | `#3F5A00` olive | `#CFF25B` lime | Accent text and icons (olive in light mode for contrast) |
| `surface` | `#F7F6F3` paper | `#0F1012` | Page background |
| `surfaceContainerLow` | `#F2F1ED` | `#15161A` | Cards |
| `surfaceContainer` | `#EDEBE6` | `#1A1C20` | Navigation bar, sheets, dialogs |
| `onSurface` | `#121316` | `#F2F1EE` | Main text |
| `onSurfaceVariant` | `#5E616A` | `#A3A6AE` | Secondary text, inactive icons |
| `outlineVariant` | `#DEDBD3` | `#2A2C33` | Card borders, dividers |

Widgets read colors from `Theme.of(context).colorScheme`, never from the constants directly.

## Typography

**Manrope**, bundled as a variable font in [assets/fonts/manrope/](../assets/fonts/manrope/) (SIL Open Font License). It is never downloaded at runtime, consistent with the offline promise.

| Style | Weight | Tracking | Use |
| --- | --- | --- | --- |
| `displaySmall` | 800 | −0.8 | Page titles |
| `displayLarge` | 800 | −1.5 | Key number (e.g. reclaimable space) |
| `headlineSmall` | 700 | −0.4 | Section and onboarding headings |
| `titleMedium` / `titleSmall` | 700 / 600 | 0 | Card titles, list rows |
| `bodyLarge` / `bodyMedium` | 400 | 0 | Reading text |
| `labelLarge` | 700 | 0 | Buttons |

Each style sets both `fontWeight` and the `wght` font variation, so the variable font renders the intended weight.

## Shapes

| Element | Shape |
| --- | --- |
| Cards, dialogs | 24 dp radius, 1 dp `outlineVariant` border, no elevation |
| Hero card (Stats) | 28 dp radius, lime |
| Bottom sheets | 24 dp top radius |
| Buttons, navigation bar | Stadium (pill) |
| Onboarding illustration | 140 dp square, 44 dp radius |

## Navigation bar

A floating pill, 56 dp high, 12 dp above the system navigation area, centered, with five icons and no labels:

| Tab | Icon (inactive / selected) |
| --- | --- |
| Photos | `image_outlined` / `image_rounded` |
| Videos | `smart_display_outlined` / `smart_display_rounded` |
| Albums | `collections_bookmark_outlined` / `collections_bookmark_rounded` |
| Stats | `donut_large_outlined` / `donut_large_rounded` |
| Settings | `tune_outlined` / `tune_rounded` |

- Background: `surfaceContainer` at 86 % opacity with a 20 px blur, so content scrolls visibly underneath.
- Selected tab: lime pill (48 × 36 dp) behind the filled icon, animated in 220 ms.
- Accessibility: every icon has a tooltip and a screen reader label, and a 56 × 48 dp touch target (checked by a test).
- Pages add `CompactNavBar.contentInset(context)` as bottom padding so the last item is never hidden.

## Page layout

Tabs use `TabPage`: 20 dp side margins, a `displaySmall` title 24 dp below the status bar, then content. There is no app bar. Album pages use a `headlineMedium` title after a back button.

## Media grid

| Element | Spec |
| --- | --- |
| Grid | Edge to edge, 2 dp gaps, square cells, 2–6 columns (default 4) |
| Section header | `titleMedium`, 20 dp side margin; "Today", "Yesterday", then full dates; months from 5 columns |
| Video badge | Bottom right, black 55 % pill, play icon and duration in white, 11 sp bold |
| Favorite badge | Bottom left, same pill with a heart |
| Loading | Grey `surfaceContainerHigh` squares (skeleton) |
| Empty and error states | 88 dp rounded-square icon, `titleLarge` title, secondary text, optional button |

## Album tiles

Two columns, 12 dp apart. Cover with 24 dp radius, then the name (`titleSmall`) and the count (`bodySmall`, secondary color). Virtual albums (Favorites) show a lime badge with their icon on the cover.

## Viewer

- Always dark, black background, whatever the app theme.
- Top bar over a black-to-transparent gradient: back button, date (`titleMedium`), file name (`bodySmall`, 70 % white).
- Tapping hides the bars and the system UI (immersive mode).
- Video controls: 72 dp lime play button in the center; at the bottom, position, slider, duration, mute and rotate over a gradient.
