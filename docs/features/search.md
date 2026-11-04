# Search

Finding photos and videos by combining criteria: part of the file name, type, favorites, folder, an area picked on the map, and a date range.

Last updated: 2026-11-04 — Visual refresh spec

## Purpose

The brief: "Combinable filters: date range, type (photo / video / screenshot), folder, favorites, file name, geographic area (picked on the map)." Everything runs on the media index in the database; nothing leaves the phone.

## User flows

1. **Open**: the magnifier in the title of the Camera, Videos and Albums tabs and of every album page (product owner's choice, 2026-10-30). The search looks **only in the timeline it was opened from** (product owner, after the first device test): Camera searches the camera's photos, Videos the videos, a folder page that folder, Favorites the favorites, the Albums tab every photo and video. It opens with the keyboard up and that whole timeline below, titled *In Camera*, *In Videos*, *In WhatsApp Images*…
2. **File name**: typing filters the results once typing pauses (300 ms); case is ignored for unaccented letters; ✕ clears the field.
3. **Criteria chips** under the field, all in sight (they wrap onto two lines). Chips that cannot narrow the timeline are left out: no type in Camera and Videos, no Folder in Camera or a folder page, no Favorites in the Favorites album.
   - **Photos**, **Videos**, **Screenshots**: one type at a time; the chip picked again goes back to every type.
   - **Dates** (asked by the product owner after the second device test): the period choices of the sort sheet (all time, last 7 days, last 30 days, this year, last year, custom range in a calendar); the sheet closes on a choice, the chip then shows the period, its ✕ removes it.
   - **Favorites**: only favorites, combined with the type.
   - **Folder**: a list of the device folders with their counts; the chip then shows the folder's name, its ✕ removes it.
   - **Area**: the map opens in picking mode (title *Choose an area*); move and zoom, then **Search this area**: the results are limited to the area shown. A cluster zooms in instead of opening. The chip then reads *Area on the map*; tapping it opens the map on that area again; its ✕ removes it.
4. **Results**: a timeline titled *In …* with the number of items, like an album: date sections, pinch, selection, viewer. Its **sort and filter** button sets the order (and the same period as the Dates chip); both stay when a criterion changes. The period shows as the Dates chip only, not again above the results.
5. **Nothing matches**: *Nothing matches*; with a date range set, the usual empty state offers to show all dates.

## How it works

| Part | File | Role |
| --- | --- | --- |
| `MediaSelection.favoritesOnly`, `nameContains` | [album.dart](../../lib/domain/album.dart) | The two criteria the selection lacked; type, folder, dates and area existed already. |
| `DateRangeChips` | [sort_filter_sheet.dart](../../lib/features/library/sort_filter_sheet.dart) | The period choices, shared by the sort sheet and the search's Dates chip. The period is the results' view (`ViewSelection.dates`), not part of the criteria. |
| Query | [media_index_repository.dart](../../lib/core/database/media_index_repository.dart) | `_matches` adds `is_favorite = 1` and `file_name LIKE '%…%'` with `%`, `_` and `\` escaped, so they match literally. |
| `SearchArgs`, `searchStart`, `SearchCriteria` | [search_controller.dart](../../lib/features/search/search_controller.dart) | `SearchArgs`: the timeline searched in (`scope`) and its name. `searchStart`: the scope as a search, with an empty `nameContains` (the Favorites album becomes `favoritesOnly`, so a type can be picked). `SearchCriteria` (Riverpod, one per scope): the criteria as a `MediaSelection`; on each change it carries the results' sort and dates to the new selection (`ViewSelection.keepFrom`) and keeps that view alive. |
| `SearchScreen` | [search_screen.dart](../../lib/features/search/search_screen.dart) | Route `/search` (`SearchArgs` as `extra`; all media without): field, chips, folder sheet, results (`MediaTimelineView` with `compact`, without the Duplicates tile). |
| `SearchButton` | [media_timeline_view.dart](../../lib/features/library/media_timeline_view.dart) | The magnifier, opening the search in its timeline; `showSearch` on the Camera and Videos timelines and album pages; in the Albums title, on all media. |
| Picking an area | [map_screen.dart](../../lib/features/map/map_screen.dart) | Route `/map/pick` (`MapScreen(pickArea: true)`, optional `GeoArea` to open on): pops the visible bounds as a `GeoArea` ([map.md](map.md)). |

- The field and chips sit above the results, outside the scrolling timeline: the timeline rebuilds as results come and go, and the field must keep its focus and keyboard.
- A search's selection always has a `nameContains`, empty without a name: it never equals the tab's own selection, so the results' sort and dates never leak into the tab, and `viewKey` saves their sort apart (`search:` prefix).
- No new table or index: a `LIKE` over 30,000 file names takes a few milliseconds in SQLite.

## Edge cases

- **Empty or blank name**: no name criterion.
- **`%` or `_` in the name**: matched as such (`100%` finds `100%_sure.jpg`, not `100x`).
- **Accented letters**: SQLite ignores case for A to Z only, so `É` does not find `é`.
- **An area across the antimeridian** (the Pacific in view): every longitude is taken, between the visible latitudes.
- **Items without a location** never match an area.
- **Without the location permission**, the picking map shows its permission card instead of the button.

## Tests

- [search_selection_test.dart](../../test/core/database/search_selection_test.dart): part of a name ignoring case and spaces around, empty name, literal `%` and `_`, favorites combined with type and name.
- [search_test.dart](../../test/features/search/search_test.dart): the magnifier in the three tabs; the search limited to Camera, Videos, a folder page and Favorites, with the chips that apply; everything without criteria, name and clear, type and favorites combined, type toggled off, a period picked and removed, folder picked and removed, area picked on the map, sort kept when a criterion changes.

## Planned look

A pill search field, and the mark in the empty state. Not built yet: [visual refresh](../visual-refresh.md), [mockup](../design-assets/mockups/screens/17-search-empty.png).

## Known limitations / future work

- No search by date typed as text, camera model or place name (no geocoding: it would need a network service or a large offline database).
- The criteria are not remembered when the search is closed.
