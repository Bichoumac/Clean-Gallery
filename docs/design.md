# Design system

Visual identity of Clean Gallery, **Éclat Soleil**: palette, typography, shapes, components, motion and logo. The interface disappears around the photos and shows its character only where there are none.

Last updated: 2026-11-04 — Visual refresh

Why this direction: [ADR 0028](decisions/0028-warm-eclat-identity.md). The mockups show an earlier yellow accent; the values here are the current ones. Built as described in the [visual refresh](visual-refresh.md).

Source: [app_theme.dart](../lib/core/theme/app_theme.dart), [app_motion.dart](../lib/core/theme/app_motion.dart), [lib/core/brand/](../lib/core/brand/) (mark, gauge, glass bars, mosaic tiles, empty state), [compact_nav_bar.dart](../lib/core/router/compact_nav_bar.dart). Mockups: [design-assets/mockups/](design-assets/mockups/).

## Principles

1. **The photos come first.** Grids, the viewer and the editor have no character of their own: neutral background, no decoration, thin monochrome icons. Warm surfaces never touch a photo grid, so they cannot change how its colors look.
2. **One accent.** Golden citron is the only color that draws attention: the selected tab, the main button, the key number on a screen. A screen has at most one large accent area, the selected tab apart.
3. **Character where there are no photos.** Onboarding, empty states, the Stats tab, the end of a sort, memories and the app icon carry the identity.
4. **Big type, little chrome.** Large bold titles replace app bars. Bars float, translucent, and can disappear. No shadows; separation comes from surface tones and thin outlines.
5. **Soft geometry.** Large radii and pills, tiles of different sizes rather than long lists. A thumbnail in a grid stays square, without corners.
6. **The kept petal.** Eight petals, one of them lit: of eight similar photos, the one worth keeping. The same mark is the icon, the Stats gauge, the Best badge and the empty states.

## Palette

The palette is fixed and does not follow the wallpaper (no Material You dynamic colors).

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `primaryContainer` | `#E8E24C` citron | `#E8E24C` citron | Selected tab, filled buttons, hero card |
| `onPrimaryContainer` | `#14110C` ink | `#14110C` ink | Text and icons on citron |
| `primary` | `#6B6600` olive | `#E8E24C` citron | Accent text and icons (olive in light mode for contrast) |
| `onPrimary` | `#FFFFFF` | `#14110C` | Text on `primary` |
| `secondary` | `#5F574A` | `#B3AB9D` | Secondary accents |
| `onSecondary` | `#FFFFFF` | `#14110C` | Text on `secondary` |
| `error` | `#C4361F` | `#FF6B5E` | Trash and destructive actions |
| `onError` | `#FFFFFF` | `#14110C` | Icons and text on `error` |
| `surface` | `#FBF8F1` cream | `#14110C` | Background of screens without a photo grid |
| `surfaceContainerLowest` | `#FFFFFF` | `#0A0A0A` | **Neutral**: background of photo grids |
| `surfaceContainerLow` | `#F6F2E8` | `#1E1A14` | Cards and tiles |
| `surfaceContainer` | `#F0EBDF` | `#26211A` | Navigation bar, sheets, dialogs |
| `surfaceContainerHigh` | `#E9E3D5` | `#2E2820` | Unlit petals, raised elements |
| `surfaceContainerHighest` | `#E2DBCB` | `#38312A` | Switch tracks, unlit petals on dark |
| `onSurface` | `#14110C` | `#F6F1E7` | Main text |
| `onSurfaceVariant` | `#5F574A` | `#B3AB9D` | Secondary text, inactive icons |
| `outline` | `#8F8675` | `#6E6556` | Borders of controls (chips, outlined buttons) |
| `outlineVariant` | `#E0D9CA` | `#332D24` | Card borders, dividers |
| `inverseSurface` | `#14110C` | `#FBF8F1` | Snackbars, scroll bubble |
| `onInverseSurface` | `#FBF8F1` | `#14110C` | Text on `inverseSurface` |

Widgets read colors from `Theme.of(context).colorScheme`, never from the constants directly. The only other colors are white and black over a photo (scrims, viewer controls) and the two logo tones below.

| Decorative tone | Value | Use |
| --- | --- | --- |
| Petal on citron, icon | `#BDB72A` | The seven unlit petals of the app icon |
| Petal on citron, large | `#CFC933` | Unlit petals on the hero card and the onboarding page |
| Petal on ink | `#857C6E` | The seven unlit petals of the logo on dark |

### Contrast

Measured values (WCAG). Normal text needs 4.5:1, large text and control borders 3:1. Unlit petals are decoration and need no ratio.

| Pair | Ratio |
| --- | --- |
| Ink on citron | 13.82:1 |
| Olive on cream / on white | 5.62:1 / 5.96:1 |
| `onSurface` on `surface`, dark / light | 16.73:1 / 17.75:1 |
| `onSurfaceVariant` on `surface`, dark / light | 8.28:1 / 6.71:1 |
| `onSurfaceVariant` on cards, dark / light | 7.61:1 / 6.37:1 |
| `onError` on `error`, dark / light | 6.74:1 / 5.39:1 |
| `outline` on `surface`, dark / light | 3.28:1 / 3.39:1 |

Citron and `error` stay apart by hue, by icon and by position, never by color alone: *Keep* is a check on the right, *Trash* a bin on the left.

## Typography

Two typefaces, both bundled and never downloaded at runtime, consistent with the offline promise (SIL Open Font License):

- **Bricolage Grotesque** for display and headline styles: page titles, section headers, key numbers.
- **Manrope** for everything else: reading text, labels, buttons.

| Style | Typeface | Size | Weight | Tracking | Use |
| --- | --- | --- | --- | --- | --- |
| `displayLarge` | Bricolage | 57 | 800 | −2 | Key number (e.g. reclaimable space), memory title |
| `displayMedium` | Bricolage | 45 | 800 | −1.5 | Onboarding headline, end of a sort |
| `displaySmall` | Bricolage | 36 | 800 | −1 | Page titles |
| `headlineLarge` | Bricolage | 32 | 800 | −0.9 | Album page titles |
| `headlineMedium` | Bricolage | 28 | 800 | −0.8 | Numbers in tiles, empty state titles |
| `headlineSmall` | Bricolage | 22 | 700 | −0.4 | Section headers ("Today"), memory card title |
| `titleLarge` | Manrope | 22 | 700 | −0.2 | Dialog titles |
| `titleMedium` / `titleSmall` | Manrope | 16 / 14 | 800 / 700 | 0 | Tile and card titles, list rows |
| `bodyLarge` / `bodyMedium` | Manrope | 16 / 14 | 400 | 0 | Reading text |
| `bodySmall` | Manrope | 12 | 500 | 0 | Counts, secondary lines |
| `labelLarge` | Manrope | 14 | 800 | 0 | Buttons |

Each style sets both `fontWeight` and the font's `wght` variation, so the variable fonts render the intended weight. Bricolage styles also set `opsz` to the font size (its axis goes from 12 to 96), which tightens large titles; `wdth` stays at 100.

Key numbers scale down to fit their card at large text sizes instead of wrapping or being clipped.

## Shapes

| Element | Shape |
| --- | --- |
| Cards, tiles, dialogs | 26 dp radius, 1 dp `outlineVariant` border, no elevation |
| Hero card (Stats) | 30 dp radius, citron, no border |
| Large album tile | 28 dp radius |
| Album covers | 22 dp radius |
| Memory card | 24 dp radius |
| Bottom sheets | 24 dp top radius |
| Buttons, chips, navigation bar | Stadium (pill) |
| Selected cell in a grid | 14 dp radius, the only rounded thumbnail |

## Logo

**Plein soleil**: a rosace of eight petals on golden citron, seven tone on tone and one in ink, at 45° (top right). Files: [design-assets/logo/](design-assets/logo/).

| File | Use |
| --- | --- |
| [app-icon.svg](design-assets/logo/app-icon.svg) | Master of the icon, square, without corners |
| [app-icon-512.png](design-assets/logo/app-icon-512.png) | Google Play listing |
| [mark-on-sun.svg](design-assets/logo/mark-on-sun.svg) | Onboarding, on citron |
| [mark-on-dark.svg](design-assets/logo/mark-on-dark.svg) | On ink, outside the app icon |
| [mark-empty-dark.svg](design-assets/logo/mark-empty-dark.svg), [mark-empty-light.svg](design-assets/logo/mark-empty-light.svg) | Empty states |
| [mark-complete.svg](design-assets/logo/mark-complete.svg) | End of a sort: all petals in ink |
| [mark-mono.svg](design-assets/logo/mark-mono.svg) | One color: unlit petals at 40 % |

**Geometry**, in a 100 × 100 box. One petal, pointing up, then rotated around the center (50, 50) every 45°:

```text
M 50,45
C 46,38  40,28  40,19      cubic to the left side
A 10,10  0 0 1  60,19      half circle over the top
C 60,28  54,38  50,45      cubic back to the center
Z
```

Rules:

- The lit petal is always at 45°. In the gauge, petals fill from the top, clockwise.
- Clear space: at least the width of one petal. The rosace never carries text, never tilts, never has a gradient or a shadow.
- Do not make the petals multicolored or translucent on white: that is the look of another well-known photo app.

## Navigation bar

A floating pill, 56 dp high, 12 dp above the system navigation area, centered, with five icons and no labels:

| Tab | Icon (inactive / selected) |
| --- | --- |
| Camera | `photo_camera_outlined` / `photo_camera_rounded` |
| Videos | `smart_display_outlined` / `smart_display_rounded` |
| Albums | `collections_bookmark_outlined` / `collections_bookmark_rounded` |
| Stats | `donut_large_outlined` / `donut_large_rounded` |
| Settings | `tune_outlined` / `tune_rounded` |

- Background: `surfaceContainer` at 72 % opacity with a 20 px blur, and a 1 dp inner line (white at 12 % in dark, black at 8 % in light), so content scrolls visibly underneath.
- Selected tab: citron pill (48 × 38 dp) behind the filled icon, animated in 220 ms.
- Accessibility: every icon has a tooltip and a screen reader label, and a 56 × 48 dp touch target (checked by a test).
- Pages add `CompactNavBar.contentInset(context)` as bottom padding so the last item is never hidden.

## Page layout

Tabs use `TabPage`, with a `displaySmall` title 24 dp below the status bar, then content. There is no app bar. Album pages use a `headlineLarge` title after a back button.

| Page kind | Background | Side margins |
| --- | --- | --- |
| Photo grid (Camera, Videos, album pages, search results, trash) | `surfaceContainerLowest` | Titles 14 dp, grid edge to edge |
| Mosaic (Albums, Stats) and cards (Settings, rituals, duplicates) | `surface` | 14 dp |
| Viewer, editor, scanner, slideshow, sort session | Black or `surfaceContainerLowest`, always dark | — |

## Mosaic

Albums and Stats use tiles instead of lists: two columns, 10 dp apart, with some tiles across the full width. A tile holds an icon or a label at the top and its title or number at the bottom. Height 96 to 118 dp, so it reads at a glance.

## Media grid

| Element | Spec |
| --- | --- |
| Grid | Edge to edge, 2 dp gaps, square cells without corners or shadows, 2–6 columns (default 4) |
| Section header | `headlineSmall`, 14 dp side margin; "Today", "Yesterday", then full dates; months from 5 columns |
| Video badge | Bottom right, black 55 % pill, play icon and duration in white, 11 sp bold |
| Favorite badge | Bottom left, same pill with a heart |
| Loading | `onSurface` at 8 % squares (skeleton), neutral on the neutral background |
| Empty and error states | See [Empty states](#empty-states) |

## Sort and filter

- Filter button (`filter_list_rounded`) at the right of the page title, with an 8 dp accent dot when the view is customized.
- Bottom sheet with a drag handle: "Sort by" choice chips, a full-width segmented button for the direction, "Period" choice chips (the custom one shows the range), *Reset* at the top right.
- Active choices as input chips under the title (date range icon or sort icon), with a delete cross.

## Fast-scroll thumb

- 6 dp wide pill (8 dp while dragging) on the right edge, 48 dp high, `onSurfaceVariant` at 60 % (accent while dragging), with a 44 dp wide touch area.
- Shown while scrolling, faded out 1.5 s after; only on lists of three screens or more.
- Bubble left of the thumb while dragging: `inverseSurface` stadium, `titleSmall` text.

## Selection

- Long press a thumbnail to start; drag without lifting to select a range; tap to add or remove.
- Selected cell: shrunk by 10 dp with 14 dp corners and a 22 dp accent check top left; other cells show a white ring.
- The navigation bar is replaced by the **selection bar** at the same place and size: close, "N selected", then up to four action icons (share, favorite, trash; restore and delete for good in the trash); beyond four actions, the fourth place is a **More** menu (⋮) with the rest (add to album, select all…).
- **Snackbars** float above the bar; those with a button (Undo, Open) close by themselves like the others (`persist: false`), so they never hide the bar for long.

## Album tiles

Two columns, 10 dp apart. Cover with 22 dp radius, then the name (`titleSmall`) and the count (`bodySmall`, secondary color). In the top mosaic, Favorites is the one citron tile; Map, Slideshows and Trash are `surfaceContainerLow` tiles.

## Settings

Cards per section (Display, Trash, Sharing, Permissions), 18 dp padding, `titleMedium` section titles. Choices use full-width segmented buttons; the retention uses a slider with its value at the right, in `primary`; permissions show their status under the name with a *Change* text button.

## Empty states

The mark replaces the 88 dp rounded-square icon: 120 to 164 dp, the seven unlit petals in `surfaceContainerHigh` (light) or `surfaceContainerHighest` (dark), the 45° petal in citron. Below it, a `headlineMedium` title, secondary text and an optional button, all centered. Error states keep an icon, in `error`, without the mark: an error is not a brand moment.

## Trash

Three-column grid with a "N days" badge (black 60 % pill, bottom left) on each item; *Empty trash* at the top right; an explanation of the retention under the title.

## Viewer

- Always dark, black background, whatever the app theme.
- Top bar over a black-to-transparent gradient: back button, date (`titleMedium`), file name (`bodySmall`, 70 % white), then the actions.
- Tapping hides the bars and the system UI (immersive mode).
- **No accent over a photo or a video.** Video controls: 72 dp round play button, white at 22 % with a 20 px blur and a 1 dp white line at 30 %, white icon; at the bottom, position, a white slider, duration, mute and rotate over a gradient.
- The accent appears only on the group strip, which is an action on duplicates: *Best* pill, frame of the photo shown, *Keep*.

## Motion

Speed is where quality shows: animations are quick, follow the finger and can be interrupted. Every animation below drops to an instant change when the system asks for reduced motion (`MediaQuery.disableAnimations`).

| Token | Value | Use |
| --- | --- | --- |
| `quick` | 150 ms, `easeOutCubic` | Fades of small elements, selection |
| `standard` | 220 ms, `easeOutCubic` | Tab pill, bars showing and hiding |
| `spring` | mass 1, stiffness 380, damping 30 | Grid to viewer, tiles, sheets |
| `springBouncy` | mass 1, stiffness 300, damping 24 | Sort card coming back, stamp |

| Moment | Behavior |
| --- | --- |
| Grid to viewer | The thumbnail grows from its place to full screen (`Hero`, already in place), with `spring`. |
| Viewer to grid | Pulling a photo down at 1× zoom shrinks it and fades the black background; released past 25 % of the height or with a flick, it flies back to its thumbnail, otherwise it springs back. |
| Pinch in a grid | Columns change with the fingers, 2 to 6. |
| Sort card | Follows the finger, tilts, shows the stamp; springs back with `springBouncy` if released early. |
| First launch | Petals appear one after the other, 45 ms apart, clockwise, the lit one last (400 ms each, `spring`). |
| Stats gauge | Petals fill one by one when the value changes. |
| End of a sort | The screen turns citron from the last card's position, then the rosace completes, last petal lit. |

## Android icon and launch

Ready-to-copy resources: [design-assets/android/res/](design-assets/android/res/).

| Item | Spec |
| --- | --- |
| Launcher icon | Adaptive: background `#E8E24C`, foreground the rosace 52 units wide in the 72 visible units, monochrome layer for themed icons. No PNG needed (`minSdk` is 30). |
| Status bar icon | One color, all eight petals, 24 dp ([ic_stat_clean_gallery.xml](design-assets/android/res/drawable/ic_stat_clean_gallery.xml)), for memories and rituals. |
| Launch screen | `surface` of the system theme (`#FBF8F1` or `#14110C`), never a full citron flash; icon on its citron circle on Android 12 and later. |
