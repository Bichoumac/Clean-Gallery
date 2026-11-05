# Progress

Status of each milestone, what is done, known issues and next steps. Update this file at the end of every milestone.

Last updated: 2026-11-05 — Milestone M11

## Milestones

| Milestone | Scope | Status |
| --- | --- | --- |
| M0 | Foundations | Merged into `main` (PR #1) |
| M1 | Navigation: timelines, albums, grid, viewer, video, sorting, date filter | Merged into `main` (PR #2) |
| M2 | Actions: favorites, sharing, multi-select, trash, basic settings | Merged into `main` (PR #3) |
| M3 | Engine level 1: indexing, dates, exact duplicates, bursts | Merged into `main` (PR #4) |
| M4 | Engine level 2: perceptual hashes, similar photos, dashboard | Merged into `main` (PR #5) |
| M5 | Cleanup: swipe mode, blurry, screenshots, large videos | Merged into `main` (PR #6) |
| M6 | Advanced viewer and editing | Merged into `main` (PR #7, 2026-10-30); filters merged after (PR #8, 2026-10-30) |
| M7 | Exploration: map, search | Merged into `main` (PR #9, 2026-10-30); map built in M6 |
| M8 | User albums | Merged into `main` (PR #10, 2026-11-01) |
| M9 | Slideshows, saved slideshows, memories, rituals | Merged into `main` (PR #11, 2026-11-04) |
| M10 | People (on-device face recognition, merging) | Postponed by the product owner on 2026-11-05, to come after M11; no code, model study in [ADR 0029](decisions/0029-face-model.md) |
| M11 | Monetization (was M8) | Built on branch `m11-monetization` on 2026-11-05, not tried on a phone |
| M12 | Polish and release preparation (was M9) | Not started |
| — | Visual refresh: Éclat Soleil identity, logo and icon | Merged into `main` (PR #13), tried on the phone 2026-11-05 |

M8 to M10 were added at the product owner's request on 2026-11-01; monetization and polish moved from M8 and M9.

## Visual refresh

The product owner chose a warm identity and a logo on 2026-11-04 ([ADR 0028](decisions/0028-warm-eclat-identity.md)) and asked to build it before M10. The target is in [design.md](design.md), the brief, mockups and the choices made while building in [visual-refresh.md](visual-refresh.md).

- **Done**: all seven steps of the brief, on branch `visual-refresh`. `flutter analyze` and the tests are clean; screens were rendered in widget tests and compared with the mockups.
- **On the phone, 2026-11-04**: the product owner's overall impression is good ("tout me paraît bien"); the checks of [testing.md](testing.md#visual-refresh--to-verify-on-a-device) were not reported one by one.
- **Accent**: changed to golden citron at the product owner's request; "beaucoup mieux" (2026-11-05).
- **Map**: slow loading and missing marker thumbnails reported, then "carte ok" after the duplicate scan was paused on the map and failures retried (2026-11-05).
- **Thumbnails missing in runs** (reported 2026-11-05, several runs of consecutive cells): failed loads stayed in Flutter's image cache, reproduced by a test and fixed ([library.md](features/library.md#thumbnails-that-fail)). Confirmed on the phone by the product owner ("ça marche", 2026-11-05).

## M11 — Monetization

### Done

- **Ads**: AdMob banner in the Albums tab and native card in the Stats tab, UMP consent after onboarding, *Privacy & ad choices* ([monetization.md](monetization.md), [ADR 0030](decisions/0030-ads-and-purchase.md)).
- **Ad before a manual slideshow** (product owner, 2026-11-05, reversing the brief's ban on interstitials for this case): at most every 5 minutes, never before a memory, ritual or saved slideshow; the slideshow never waits for it.
- **Remove ads**: non-consumable `remove_ads`, acknowledged, checked at each launch, restored, cached so no ad flashes; the SDK never starts for an ad-free user. Offered in Settings, next to the banner, and once after more than 500 MB deleted for good.
- Five architecture tests guard the placements and the requests. No schema change. 472 tests; a profile APK builds.

### Decisions

- **People moved after M11** (product owner, 2026-11-05), see [ADR 0029](decisions/0029-face-model.md).
- **Android backup stays on** (product owner, 2026-11-05), so the app's data can follow the user to a new phone; the privacy policy says so ([platform-android.md](platform-android.md#android-backup)).
- **Privacy policy**: published by the product owner at <https://sites.google.com/view/clean-gallery-privacy> (2026-11-05); to link from the app in M12.
- **Application ID**: `com.bichoumac.clean_gallery` confirmed by the product owner as final (2026-11-05).
- **Play Console account**: personal, so the closed test of 12 testers for 14 days applies, and the product owner cannot gather 12 testers (2026-11-05). The way to publish is open.
- **Banner**: standard 320 × 50 dp, the link moved to the end of the list, after the product owner found the large adaptive banner, then the strip, too big (2026-11-05).
- **`ACCESS_ADSERVICES_TOPICS` removed** at the product owner's request (2026-11-05).
- **The offer** follows a deletion for good from the Trash screen; moving to the trash frees nothing yet.
- **Native template** rather than a Kotlin factory; to review once seen on the phone.

### Known issues

- **On the phone, 2026-11-05**: items 1 to 9 reported as OK as a whole ("tests sur téléphone ok"), not one by one, on the build before the last banner change. The purchase itself (items 10 to 15) has not run. Checklist: [testing.md](testing.md#m11--monetization-to-verify-on-a-device).
- The purchase cannot be tried until the product owner has set up the Play Console; ads need AdMob before release ([outside setup](monetization.md#set-up-outside-the-code)).
- With Google's test app ID, whether the consent form appears is unknown; if it fails on a first launch, no ad is requested.
- Release APK size with the SDKs not measured (26.6 MB before them).

### Next steps

1. The product owner checks the smaller banner strip.
2. Decide how to publish without 12 testers.
3. The product owner's AdMob and Play Console setup, then items 10 to 15.
4. M12, then M10 when it resumes.

## New features — decisions (2026-11-01)

The product owner asked for People (face recognition with merging), user albums and slideshows with automatic memories, and answered the open questions the same day. The specification is in [prompt.md](../prompt.md#user-albums-added-2026-11-01).

| # | Topic | Decision |
| --- | --- | --- |
| Q1 | People: on or off by default | Opt-in, explained before the first scan. |
| Q2 | People: videos | Photos only. |
| Q3 | People in the info panel | Yes. |
| Q4 | Kind of album | App albums in the database; no file is ever moved, copied or deleted for an album. |
| Q5 | Memories | Card in the app, and a small notification once a week, **without a background task**: scheduled notifications only, the slideshow is built when it is opened. Rituals: recurring slideshows the user schedules. |
| Q6 | Videos in slideshows | Yes, muted, 10 s at most. |
| Q7 | Music | The user picks: free tracks bundled with the app, or a track from the phone. |
| Q8 | Saving and sharing | Slideshows are saved on the user's tap and play again at any time (no video file). Sharing and casting to a TV: later, kept in mind. |
| Q9 | Order | M8 albums, M9 slideshows and memories, M10 People, M11 monetization, M12 polish. |
| — | Face model | Bundled in the app, runs on the phone only, never downloaded, no cloud or ML Kit; a test checks it uses no network. |

The brief excluded all machine learning; on-device face recognition for People is the one exception.

## M9 — Slideshows and memories

### Done

- **Slideshows** (2026-11-03, branch `m9-slideshows-memories`): a *Slideshow* button on every album page (folders, All media, Favorites, user albums, search results, map areas), *Slideshow* in the selection's More menu, and Albums → Slideshows → *Slideshow* for a period. Options sheet (time per photo 3 / 5 / 8 s, crossfade or slow zoom, by date or shuffled, videos muted 10 s at most, skipping duplicates and blurry photos, music), remembered. Full-screen player with the screen kept on, controls on a tap, end screen. **Saved slideshows** (items in order and options, no video file) in the Albums tab: play, rename, delete with Undo ([features/slideshow.md](features/slideshow.md), [ADR 0026](decisions/0026-saved-slideshows-without-video.md)).
- **Music**: none, or a track from the phone through the system file picker (no audio permission, a persistable read access to that file only, given back when unused). Bundled tracks: the list is ready but empty (see Decisions).
- **Memories** (2026-11-03): "On this day" and "This week, N years ago" from the camera's good photos, found while the app is open; cards at the top of the Camera tab (play, ✕ with Undo); a *Memories* list in the Albums tab ([features/memories.md](features/memories.md)).
- **Rituals and notifications**, without background work: Settings → Slideshows and memories (memories off / weekly / monthly, notification with day and time, rituals, slideshow defaults); the Rituals page; notifications planned by the app and shown by a receiver that reads nothing else, set again after a reboot ([ADR 0027](decisions/0027-notifications-without-background-work.md)).
- **Custom slideshow album** (2026-11-04, asked by the product owner after installing the first build): the custom slideshow (Albums → Slideshows → *Slideshow*) asks for an album (all media, Favorites, a user album or a folder) as well as the period. Fixed the same day: closing a slideshow without music while it played raised an error when the screen closed, which could leave the screen kept on.
- Schema version 7: `slideshows`, `slideshow_items`, `memories`, `rituals` ([database.md](database.md#migrations)). 421 tests. Device checklist: [testing.md](testing.md#m9--slideshows-and-memories-to-verify-on-a-device) items 95 to 115.

### Decisions

- **Bundled music** (2026-11-03, product owner): M9 ships *None* and *Track from the phone*; the product owner picks 2 or 3 CC0 tracks, then they are added to `bundledTracks` with their credits in About.
- **People** entry points (slideshow of a person, ritual on a person) come with M10.
- **Inexact notification times** (2026-11-03, product owner): no "Alarms & reminders" permission; a notification may come a few minutes late.
- **Memory thresholds** (2026-11-03, product owner): 8 good photos for a week, 6 for a day; weeks run Monday to Sunday. To adjust after trying them on real libraries.
- **Memories notification off by default**: the spec asks for the permission when it is turned on, never at onboarding, so it starts off; memories themselves are on (weekly) and show as cards.
- **One memory per year**: the day when it has enough photos, otherwise the week, so two cards never show the same photos.
- **Memory notifications only when there are memories**: the app checks each planned date while it is open, so none says "ready" for nothing.
- **No new package**: `video_player` already plays videos; the music, file picker, screen and notifications are on the existing native channel (ADR 0026, ADR 0027).

### Known issues

- Tried on the Galaxy A54 on 2026-11-04: "ça marche bien" (an overall report, not item by item; [testing.md](testing.md#m9--slideshows-and-memories-to-verify-on-a-device)).
- Notifications are planned 8 weeks (weekly) or 6 months (monthly) ahead; they stop if the app is not opened for that long, until the next launch.
- Memories use the camera's photos only (no videos, no other folders).

### Next steps

1. ~~Device test, then push~~ done on 2026-11-04; the product owner opens and merges the pull request.
2. The product owner's CC0 tracks for the bundled music.
3. **M10**: People.

## M8 — User albums

### Done

- **User albums** (2026-11-01, branch `specs-albums-slideshows-people`, with the M9 and M10 specification): *My albums* in the Albums tab, *New album*, *Add to album* from any selection (More menu) and from the viewer, album pages with *Remove from album* (Undo), *Use as cover*, *Rename*, *Delete album* (Undo). Lists in the database only, schema version 6 ([features/user-albums.md](features/user-albums.md), [ADR 0025](decisions/0025-user-albums-in-the-database.md)). 387 tests. Device checklist: [testing.md](testing.md#m8--user-albums-to-verify-on-a-device) items 84 to 94.

### Decisions

- **App albums only**: no file moved, copied or deleted (product owner, 2026-11-01).
- **Selection bar**: three buttons and a **More** menu, since a fourth button left too little room for the count on a phone; *Add to album* and *Select all* are in the menu. To review after the device test.
- **Without any album**, *My albums* is one line and a button, so the folders do not move down by a whole row of tiles.
- Albums are listed newest first; names are unique ignoring case.

### Known issues

- Confirmed on the Galaxy A54 on 2026-11-01, items 84 to 94 ("ça marche"); the selection bar's More menu approved as is.
- Fixed at the product owner's request (2026-11-01): snackbars with a button (Undo, Open) stayed until closed, covering the selection bar, since Flutter keeps them by default; they now close by themselves (`persist: false`).

### Next steps

1. ~~Device test (items 84 to 94), then push~~ done on 2026-11-01; merged as PR #10.
2. ~~**M9**: slideshows and memories~~ built on 2026-11-03.

## M7 — Exploration

The map and its mini map were built in M6 (see below). M7 adds the search.

### Done

- **Search** (2026-10-30, branch `m7-search`): a magnifier in the Camera, Videos and Albums titles (product owner's choice the same day) opens a file name field and criteria chips: Photos / Videos / Screenshots, Favorites, Folder, Area (picked on the map, new picking mode). Results as a timeline with its own sort and date range, kept when a criterion changes. `MediaSelection` gains `favoritesOnly` and `nameContains`; no schema change ([features/search.md](features/search.md)). Device checklist: [testing.md](testing.md#m7--search-to-verify-on-a-device) items 71 to 78.
- **First device test of the search** (2026-10-30, product owner): everything worked, but the search looked through every item instead of the tab or folder it was opened from. Now it searches only that timeline (Camera, Videos, a folder, Favorites; the Albums tab searches everything), album pages get the magnifier too, chips that cannot narrow it are hidden; the results' sort is saved apart from the tab's. 367 tests.
- **Second device test** (2026-10-30, product owner): the scoped search works (items 79 to 82, "c'est très bien"); a search by date asked for. Added: a **Dates** chip among the criteria (presets and custom range), sharing the period choices with the sort sheet. 368 tests; item 83 confirmed on the phone the same day. Branch pushed and pull request opened.

### Decisions

- **Entry point**: a magnifier in the tab titles rather than a tile in Albums (product owner, 2026-10-30).
- **Scope**: the search looks only in the timeline it was opened from (product owner, 2026-10-30, after the first device test).
- **Dates**: first only in the results' sort and filter sheet, as in every other timeline; a **Dates** chip among the criteria was added at the product owner's request after the second device test (2026-10-30). Both set the same period.
- **Criteria chips wrap** onto two lines instead of scrolling sideways, so every criterion is in sight.

### Known issues

- Accented capitals do not match lowercase letters in file names (SQLite `LIKE`).

### Next steps

1. ~~Device tests and pull request~~ done on 2026-10-30; merged as PR #9 the same day.
2. **M8**: user albums, built on 2026-11-01 (see above).

## M6 — Advanced viewer and editing

In parts, each tested on the phone: 1. the info panel; stacks in the timelines and the map (added at the product owner's request on 2026-10-28, before the editor; the map comes from M7); 2. the editor (crop, rotate, flip, adjustments); 3. filters and saving.

### Done

- **Filters** (2026-10-30, branch `m6-filters`, after PR #7 was merged): a Filters tool with eleven thumbnails (None and ten looks) and a Strength slider; each filter is a color matrix applied before the adjustments ([features/editor.md](features/editor.md), [ADR 0023](decisions/0023-editor-color-matrix-preview.md)). Confirmed on the Galaxy A54 the same day, items 65 to 70 all OK ([testing.md](testing.md#m6--viewer-and-editing-to-verify-on-a-device)); 353 tests.
- **Hazy photos are no longer blurry** (M5 follow-up): contrast measured and stored (schema version 4), blurry = sharpness below 30 and relative sharpness below 150, threshold read on the product owner's photos; only photos below 30 are analysed again ([ADR 0021](decisions/0021-hazy-photos-are-not-blurry.md)).
- **Info panel** (part 1): a Details button in the viewer opens a bottom sheet over a blurred, translucent background with the date and its source, name, path, resolution, size, duration, camera, lens, ISO, aperture, shutter speed, focal length and location; EXIF read by the new native method `mediaMetadata` ([features/viewer.md](features/viewer.md#info-panel)). After the first device test: the panel ends above the navigation bar and takes up to 90 % of the screen; the location opens the map app (`openMap`), a button copies it.
- **Stacks in the timelines**, asked by the product owner on 2026-10-28 before the editor: consecutive items of one duplicate group taken the same day fold into one thumbnail with a count badge; a tap unfolds it in place, a button on its cover folds it again; selecting a folded stack selects all its items. All groups stack (copies, bursts, similar photos); not in cleanup lists nor in name, size or duration order ([features/library.md](features/library.md#stacks)).
- **Editor** (part 2), 2026-10-28: an Edit button in the viewer (photos) opens a full-screen editor: crop with handles and shapes, rotate, flip, five color adjustments previewed live with one color matrix, Reset, a question before discarding changes. The edit is plain data (`PhotoEdit`), the matrix math pure Dart ([features/editor.md](features/editor.md), [ADR 0023](decisions/0023-editor-color-matrix-preview.md)).
- **Device test of the editor extensions and scanner** (2026-10-29): blur and pixelate covered the whole photo (fixed: clip instead of a blend mask); after the fix the product owner reported "everything works" (items 45 to 64). 344 tests. Branch pushed and pull request opened the same day; filters left for later.
- **Editor extensions and scanner** (2026-10-29, product owner's list): straighten, vignette, Enhance (histogram auto levels, no AI), Before/After, texts, blur and pixelate brushes, and a document scanner from a photo; batch editing not wanted. Saving now renders in Flutter (one paint function for preview and save). 342 tests; build installed on the phone; to test: [testing.md](testing.md#m6--viewer-and-editing-to-verify-on-a-device) items 45 to 64 ([features/editor.md](features/editor.md), [features/scan.md](features/scan.md), ADRs 0023 and 0024).
- **After the first device test of the editor** (2026-10-29, product owner): sliders were slow to start and to follow (fixed: the preview is painted on a canvas); **saving** (brought forward from part 3: *Save as a copy* or *Replace the original*, native `saveEditedPhoto`, EXIF kept); a **pencil** (six colors, three widths, Undo); the viewer's **actions moved to the bottom**. 320 tests; not seen on the device yet (items 45 to 52).
- **Sort by number of duplicates**, asked by the product owner on 2026-10-28 "wherever it applies": the duplicates screen, every timeline's sort sheet and the Albums folders ([features/library.md](features/library.md#sorting-and-date-filter), [features/duplicates.md](features/duplicates.md#user-flows)). Found on the way: a hero clash when opening the duplicates screen (or the viewer) from an album page, in debug builds only; hidden tabs now turn their heroes off.
- **Info panel**: more transparent (40 % black, blur σ 22), and pulled down from the top of its content it closes (product owner, 2026-10-28).
- **Group strip in the viewer**, asked by the product owner on 2026-10-28: a photo of a duplicate group shows the group's thumbnails at the bottom, scrolling sideways, the best one marked; large **Trash** and **Keep** buttons sort it photo by photo, with Undo ([features/viewer.md](features/viewer.md#group-strip)).
- **Map** (from M7), asked by the product owner on 2026-10-28 before the editor: Albums → Map shows located photos and videos on OpenStreetMap, in clusters with the newest item's thumbnail and a count; a cluster opens the grid of its area, a single item the viewer. Locations read by a new scan (native `locations`, schema version 5 `assets.location_read`), only with the location permission. The info panel gets its **mini map**. `INTERNET` added to the release manifest for the tiles ([features/map.md](features/map.md), [ADR 0022](decisions/0022-map-tiles-and-grid-clusters.md)).
- **Quality measures in the info panel**, at the product owner's request: sharpness (S), relative sharpness (N), brightness (B) and contrast (C) of the photo, measured by the engine's own code, and whether it is offered as blurry or too dark. Kept so the thresholds can be checked on real photos.

### Decisions

- **Stacks**: every kind of group stacks, and a tap unfolds the stack in place (rather than opening the viewer or the duplicates screen). Chosen by the product owner on 2026-10-28.
- The info panel's **mini map moves to M7**, with the map itself (approved by the product owner on 2026-10-27); the map was then brought forward to M6 on 2026-10-28, so the mini map is back in M6.
- **Map**: own grid clustering instead of `flutter_map_marker_cluster`, so a cluster is a rectangle its grid can list; the release app declares `INTERNET`; tiles from OpenStreetMap's servers ([ADR 0022](decisions/0022-map-tiles-and-grid-clusters.md)).

### Known issues

- Part 1 and the hazy photo rule confirmed on the Galaxy A54 on 2026-10-27 ("all good", [testing.md](testing.md#m6--viewer-and-editing-to-verify-on-a-device)). The quality row added afterwards is covered by a test, not seen on the device yet.
- The hazy threshold (150) comes from a handful of photos; the quality row lets the product owner report others.
- **Stacks, map and group strip confirmed on the Galaxy A54** on 2026-10-28 ("everything works", [testing.md](testing.md#m6--viewer-and-editing-to-verify-on-a-device), items 11 to 31); then the info panel change and the duplicates sorts, also confirmed the same day (items 32 to 36); 287 tests. The first reading of every location was not timed. Kept checks of the group strip are not saved.
- **Stacks** show once the analysis has grouped the photos; there is no setting to turn them off.

### Next steps

Plan to resume, in order. Each part ends with a commit, a release build installed on the phone, and a numbered checklist for the product owner.

1. ~~**Part 2, the editor**~~ done on 2026-10-28, as planned below:
   - an **Edit** button in the viewer's top bar (photos only), opening a full-screen editor route above the tabs, dark like the viewer, no ads;
   - **crop** with handles and ratios free, 1:1, 4:3, 16:9 (and their portrait forms), **rotate** by 90°, **flip** horizontally;
   - **adjustments** with sliders: brightness, contrast, saturation, exposure, warmth; previewed live on a screen-sized image with a `ColorFilter.matrix` (one 5 × 4 color matrix composed from all sliders), so moving a slider never re-encodes the photo;
   - the edit described as plain data in `lib/domain/` (crop rectangle, quarter turns, flip, adjustment values, later the filter), with the matrix math in pure Dart (`lib/analysis/` or `lib/domain/`, no Flutter import) and unit tests;
   - Cancel asks before dropping changes; an ADR for the approach (preview with color matrices, saving natively).
2. ~~**Part 3, filters**~~ done on 2026-10-30 (branch `m6-filters`; saving natively and EXIF were done on 2026-10-29 in another way, see Done). The original plan:
   - about ten **filters** with thumbnail previews: Black & White, Sepia, Vintage, Warm, Cool, Vivid, Fade, Dramatic, Noir, Soft, each a color matrix combined with the adjustments;
   - **saving natively** (new `PlatformBridge`/`MediaSource` method, Kotlin): decode the full photo, apply crop, rotation, flip and the color matrix (`ColorMatrixColorFilter` on a `Canvas`), encode JPEG, insert it with MediaStore in the same folder; **Save as copy** by default; **Replace original** puts the original in the app trash (never deleted directly);
   - **EXIF kept**: copy the original's tags with `ExifInterface`, orientation set to normal, new width and height;
   - the new photo indexed at once and shown in the viewer.
3. ~~**End of M6**~~ merged as PR #7 on 2026-10-30; filters follow in their own pull request from `m6-filters`, tested on the phone on 2026-10-30. Original plan: summary, test instructions and known issues; `CHANGELOG.md` section, pull request file (title and description) and the link `https://github.com/Bichoumac/Clean-Gallery/pull/new/m6-viewer`.
4. **M7**: search with combinable filters, including an area picked on the map (the map itself is done).
5. Later: sort mode entry from album pages.

## M5 — Cleanup

Three parts, each committed and tested on the phone: 1. old screenshots and large videos; 2. blurry and dark photos; 3. swipe mode.

### Done

- **Screenshots** recognized while indexing: a `Screenshots` folder, a "Screenshot…" name, or a PNG at the display's size (index rules version 3, [analysis-engine.md](analysis-engine.md#screenshots)).
- **Cleanup lists** opened from the Stats tab: *Old screenshots* (older than 30 days by default) and *Large videos* (from 100 MB, largest first), as timelines with their rule and total under the title, **Select all** and move to the trash ([features/cleanup.md](features/cleanup.md)). **Select all** also appears in every grid's selection bar.
- **Settings → Cleanup**: screenshot age (7 d / 30 d / 90 d / 1 yr) and large video size (50 / 100 / 250 / 500 MB).
- **Stats**: the two categories count in the space that could be freed, each item once ([features/stats.md](features/stats.md)).
- **Blurry and dark photos** (part 2): sharpness (variance of the Laplacian) and brightness measured with the perceptual hashes, in one pass over 256-pixel thumbnails; schema version 3 adds `assets.brightness`, analysis version 2 analyses every photo again once ([ADR 0020](decisions/0020-blur-and-brightness-with-the-hashes.md), [analysis-engine.md](analysis-engine.md#blurry-and-dark-photos)). A *Blurry photos* cleanup list and Stats row; screenshots left out.
- **Best pick** now prefers the sharper of two photos of the same resolution (bursts, close shots); a blurry member of a duplicate group is labelled **Blurry**.
- **Sort mode (swipe)** (part 3), from the Stats tab: sources (all photos, blurry photos, old screenshots, each month, each folder), oldest first; swipe or buttons to trash, keep or keep as a favorite; **Undo** always visible, as many levels as needed, the card flying back; sessions saved in `swipe_history` and resumed; progress "42 / 300" and an end summary ([features/swipe.md](features/swipe.md)).

### Decisions

- Sharpness and brightness will be measured with the perceptual hashes, in one pass over 256-pixel grayscale thumbnails instead of 128: more reliable blur detection; every photo is read once more (about 25 minutes on the product owner's 20,000 photos). Chosen by the product owner on 2026-10-27.
- Swipe mode shows the oldest photos first by default (product owner, 2026-10-27).

### Known issues

- All three parts confirmed on the Galaxy A54 on 2026-10-27 ([testing.md](testing.md#m5--cleanup-to-verify-on-a-device)), with one false positive: some **night photos with lights, hazy from mist**, are listed as blurry. The blur (30) and darkness (20) thresholds come from synthetic photos; flat scenes (sky, fog, a wall) may also be listed.

### Next steps

1. Stack similar photos in the timelines: done in M6 (2026-10-28).

## M4 — Engine level 2

### Done

- **Perceptual hashes**: dHash and pHash of every photo from a 128-pixel grayscale thumbnail rendered by MediaStore's cache (new native method `grayThumbnails`), computed in a Dart isolate, saved every 16 photos (40 until 2026-10-27), reset when the file changes ([ADR 0018](decisions/0018-perceptual-hashes-from-thumbnails.md), [analysis-engine.md](analysis-engine.md#similar-photos)).
- **Similar photos**: the brief's two rules (strict distance and aspect ratio; loose distance within a time window), union-find groups, confidence score; certain duplicates kept apart. Found by multi-index hashing instead of a BK-tree, **a deviation to approve** ([ADR 0019](decisions/0019-similar-photo-search.md)).
- **Duplicates screen**: choice chips **All**, **Identical copies**, **Bursts**, **Similar photos** (added after the device test, at the product owner's request), one section per kind under All; **Not duplicates** on similar groups (stored in `ignored_pairs`, kept by *Analyze the library again*); an item in two groups counted once; buttons stack with large text ([features/duplicates.md](features/duplicates.md)).
- **Best pick** applies to similar groups (favorite, resolution, size, date); sharpness joins it in M5.
- **Sensitivity** in Settings: Low / Medium / High and an advanced mode with the three thresholds; changes regroup in seconds without reading thumbnails ([features/settings.md](features/settings.md)).
- **Storage dashboard** in the Stats tab: space used by photos and videos, space that cleaning could free, by category (identical copies, bursts, similar photos, trash), each opening its tool ([features/stats.md](features/stats.md)).
- Synthetic test photo set generated in memory (recompressed, resized, brightened, cropped, moved subject, unrelated scenes) with false positive regression tests.

### Verified

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test --timeout 60s` | 197 tests pass (after the fixes and chips of 2026-10-27) |
| `flutter build apk --release --target-platform android-arm64` | Builds (Kotlin `grayThumbnails` compiles) |
| Search speed (AOT, development laptop, 30,000 photos) | Grouping 0.6–1.1 s at Medium, 1.4–2.6 s at High; hashing 1–2.5 ms per photo ([analysis-engine.md](analysis-engine.md#performance-2)) |
| Galaxy A54 | First test on 2026-10-27: no similar photos found. After the fixes, second test the same day: progress, resume after leaving the app, similar groups during the scan, close shots grouped, no false positive seen, Not duplicates, sensitivity and Stats rows confirmed. Not tested yet: WhatsApp copy, cleaning from Stats, *Analyze the library again* ([testing.md](testing.md#m4--similar-photos-and-stats-to-verify-on-a-device)) |

### Decisions

- Pixels from MediaStore's thumbnail cache, hashes in Dart ([ADR 0018](decisions/0018-perceptual-hashes-from-thumbnails.md)).
- Multi-index hashing instead of the brief's BK-tree, which was slower than comparing every pair on pHashes; advanced mode strict threshold capped at 10 ([ADR 0019](decisions/0019-similar-photo-search.md)). Approved by the product owner on 2026-10-27.
- Presets: Low 4 / 10 / 5 s, Medium 6 / 12 / 10 s (the brief's defaults), High 8 / 14 / 30 s.
- "Not duplicates" only on similar groups: certain duplicates are identical by definition.
- Similar groups pre-select every photo but the best, as the brief asks; kept by the product owner on 2026-10-27.

### Known issues

- **First device test: no similar groups.** Fixed on 2026-10-27 (progress shown, groups rebuilt every 1,000 photos, failing thumbnail batches skipped, native calls always reply) and confirmed on the phone; which of the two causes it was is not known.
- **The first analysis is long**: about 25 minutes for 20,000 photos on the Galaxy A54 (860 photos a minute with four threads, 760 with two), limited by MediaStore's thumbnail rendering. Only once: later scans read new photos only. Embedded JPEG thumbnails could be faster; not tried.
- **Similar photos are not stacked in the timelines**, only grouped on the duplicates screen. The product owner wants stacking later (M5 or after).
- **Viewer blurry until zoomed in**: MediaStore's thumbnail cache stops at 512 px on the Galaxy A54, so the "screen-sized" preview was a 384 × 512 thumbnail stretched. Fixed on 2026-10-27 (preview decoded from the file, 0.3 to 0.7 s) and confirmed on the phone. Pinch zoom, which went to the page view, fixed the same day ([testing.md](testing.md#m4--similar-photos-and-stats-to-verify-on-a-device)).
- Every item of the M4 checklist was confirmed on the Galaxy A54 on 2026-10-27, pinch zoom included. The false positive rate was only judged by eye on one library.
- The camera model and GPS bonuses of the confidence score do not apply yet: those columns are filled in M6 and M7. The score is stored, not shown.
- A photo whose thumbnail cannot be rendered is not compared until its file changes.
- Videos are not compared (brief: same duration, resolution and close dates); not part of M4's list.
- The development laptop's CPU was throttled to 600 MHz during this milestone: tests took about 3 minutes instead of 1, and benchmark times vary by about 2×.

### Next steps

1. Review and merge the M4 pull request.
2. M5: swipe mode, blurry photos (sharpness also refines the best pick), screenshots, large videos.
4. Later: stack similar photos in the timelines (product owner's request, 2026-10-27).

## M3 — Engine level 1

### Done

- **Persistent media index**: every list reads the `assets` table, so the library shows at once at launch; a sync at launch, on return to the foreground and on pull-to-refresh applies only what changed in MediaStore ([ADR 0015](decisions/0015-persistent-media-index.md), [features/library.md](features/library.md#media-index)).
- Schema version 2 with a migration that keeps the M2 trash ([database.md](database.md#migrations)).
- Native `mediaSnapshot` and `mediaDetails` replace `albumSummaries`, `mediaSizes` and `photo_manager` listing ([platform-android.md](platform-android.md#media-access)).
- **Capture dates**: resolved during the sync from the photo's metadata, then its file name, then the file date; timelines use them unless **Corrected dates** is off in Settings, at the product owner's request ([analysis-engine.md](analysis-engine.md#capture-date), [ADR 0016](decisions/0016-capture-dates-at-index-time.md)).
- **Exact duplicates**: items sharing their size are hashed (SHA-256, natively, incremental), identical hashes are grouped; a Duplicates tile at the top of every grid opens the groups of that grid, with the Best badge, pre-selected extra copies, per-group and global cleaning to the trash ([features/duplicates.md](features/duplicates.md), [ADR 0017](decisions/0017-exact-duplicates-sha256.md)).
- **Analyze the library again** in Settings: forgets every analysis result and works it out again; it replaces the brief's "clear cache", since the app's only cache is the index ([features/settings.md](features/settings.md)).
- **Bursts**: Samsung and Google camera burst names give a burst id at index time; shots of one burst form a group under Certain duplicates, labelled Burst ([analysis-engine.md](analysis-engine.md#bursts)). Close-in-time photos without a burst name are left to similar photos (M4).

### Verified

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test --timeout 60s` | 155 tests pass |
| Galaxy A54 (release build) | Media index confirmed by the product owner on 2026-10-26: migration of the M2 trash, instant display at launch, changes from other apps picked up on return, scroll position kept ([testing.md](testing.md#m3--media-index-to-verify-on-a-device)). Limited access and a fresh install not tested. Capture dates confirmed on 2026-10-26: received photos at their real date, camera photos unchanged, Corrected dates switch ([testing.md](testing.md#m3--capture-dates-to-verify-on-a-device)). Exact duplicates confirmed working on 2026-10-26, file path under each copy confirmed too ([testing.md](testing.md#m3--exact-duplicates-to-verify-on-a-device)). Bursts confirmed on 2026-10-26. *Analyze the library again* not tested yet (item 26 of [testing.md](testing.md#m3--bursts-to-verify-on-a-device)). |

### Decisions

- Lists read a persistent index synced with MediaStore by `GENERATION_MODIFIED` ([ADR 0015](decisions/0015-persistent-media-index.md)).
- Capture dates resolved at index time from MediaStore's metadata date and the file name, no EXIF reading; corrected dates on by default with a setting, as the product owner chose ([ADR 0016](decisions/0016-capture-dates-at-index-time.md)).
- SHA-256 on size collisions instead of xxHash ([ADR 0017](decisions/0017-exact-duplicates-sha256.md)).
- No "less than a second apart" burst rule: not certain duplicates ([analysis-engine.md](analysis-engine.md#bursts)).

### Known issues

- Photos taken while the app stays in the foreground appear after pull-to-refresh or the next return to the app.
- Not verified on a device: limited access (Android 14+ partial selection), a first install on a large library without M2 data, *Analyze the library again*.
- Burst shots are only recognized by their file name (Samsung, Google Camera); other cameras' bursts are left to similar photos (M4).
- The best shot of a burst is the largest file until sharpness is measured (M5).
- "Not duplicates" comes with similar photos in M4, as the brief plans; the Stats tab's Duplicates card in M5.

### Next steps

1. ~~Review and merge the M3 pull request.~~ Merged (PR #4).
2. ~~M4: perceptual hashes, BK-tree, similar photos, ignored pairs ("Not duplicates"), adjustable thresholds, storage dashboard.~~ Done, see M4.

## M2 — Actions

### Done

- System favorites from the viewer and selections ([features/favorites.md](features/favorites.md)).
- Sharing through the system share sheet, with GPS location removed from photos by default ([features/sharing.md](features/sharing.md), [ADR 0014](decisions/0014-native-sharing.md)).
- Multi-select: long press, drag to select a range with auto-scroll, selection bar with share, favorite, trash ([features/library.md](features/library.md#selection-and-actions)).
- App trash: every delete goes through it, *Undo*, Trash page with days left, restore, delete for good, daily expiry offer ([features/trash.md](features/trash.md)).
- Settings tab: theme, language, default columns, trash retention, location on share, permissions; sort of each view saved ([features/settings.md](features/settings.md)).
- First tab changed to **Camera** (camera photos only) at the product owner's request; everything else in Albums → All media.
- Video thumbnails fall back to the embedded cover or the frame at 10 %.

### Verified

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test --timeout 60s` | 101 tests pass |
| Galaxy A54 (release build) | Confirmed by the product owner: favorites, drag selection, trash and undo, delete for good, sharing, theme, language, columns, Camera tab, video thumbnails, fluidity. Details in [testing.md](testing.md#m2--to-verify-on-a-device). |

### Decisions

- **Purge at launch and resume** instead of a daily WorkManager task, accepted by the product owner ([ADR 0013](decisions/0013-trash-purge-without-background-job.md)).
- **App trash kept** rather than Android's trash ([features/trash.md](features/trash.md#known-limitations--future-work)).

### Known issues

- Whether `createFavoriteRequest` skips the confirmation with Media management is to be checked on a device.
- Video location is not removed when sharing (warned); HEIC copies lose all metadata.

### Not verified yet

- Behaviour with Media management (no system prompt for favorites and deletion), the expiry offer the next day, HEIC and video sharing, restore, sort restored after a restart, permission refresh ([testing.md](testing.md#m2--to-verify-on-a-device)).

### Next steps

1. ~~Review and merge the M2 pull request.~~ Merged (PR #3).
2. M3: persistent media index (cache) so lists show instantly at launch, then dates, exact duplicates and bursts.

## M1 — Navigation

### Done

- Photos and Videos timelines with date headers, chunked loading and pull-to-refresh ([features/library.md](features/library.md)).
- Pinch-to-zoom grid, 2–6 columns, with video durations and favorite hearts.
- Albums tab: All media, Favorites, device folders, album pages.
- Viewer: swipe, Hero transition, zoom, immersive mode; video playback with own controls ([features/viewer.md](features/viewer.md)).
- Access, limited-access, empty, error and skeleton states.
- Sorting and date filter in every timeline ([ADR 0012](decisions/0012-sort-and-date-filter.md)).
- Fast-scroll thumb with month or size bubble; grid and viewer performance work after the first device test.
- `MediaSource` on `photo_manager`, own image providers ([ADR 0009](decisions/0009-media-access.md)); `InteractiveViewer` for zoom ([ADR 0010](decisions/0010-photo-zoom.md)); `video_player` ([ADR 0011](decisions/0011-video-playback.md)).

### Verified

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test` | 68 tests pass |
| Galaxy A54 (Android 16) | Confirmed by the product owner: timelines, sorting, date filters, durations, Favorites, pinch, fast-scroll thumb, viewer swipe, and speed of Photos, Videos, Albums and the viewer. Details in [testing.md](testing.md#m1--to-verify-on-a-device). |
| Device checklist | [testing.md](testing.md#m1--to-verify-on-a-device) |

### Known issues

- New photos only appear after pull-to-refresh (automatic updates come with indexing in M3).
- The column count, sort and date filter reset at each launch. Solved in M2 for the column count and the sort; the date filter stays per session on purpose.
- Scrolling performance with very large libraries is not measured yet.

### Not verified yet

- Video progress bar fix (covered by a layout test, not re-confirmed on the phone).
- Zoom details, immersive mode, rotation, HEIC and very large photos, pull-to-refresh after a new photo, Android 14+ partial access, date filter on a folder.
- CI on GitHub for this branch (the repository is private; its status cannot be read from the development machine).

## M0 — Foundations

Merged into `main`. Summary:

- Flutter project (Android only), `minSdk 30`, `targetSdk 36`, `compileSdk 37`, strict lints, AGP 9.4.1 / Gradle 9.6.0 ([ADR 0007](decisions/0007-android-toolchain.md)).
- Architecture with tested dependency rules ([architecture.md](architecture.md)); Drift schema v1 ([database.md](database.md)).
- Own visual identity and five icon-only tabs ([design.md](design.md), [ADR 0008](decisions/0008-navigation-and-visual-identity.md)).
- Kotlin channel for "Media management" ([platform-android.md](platform-android.md)); onboarding and permissions ([features/onboarding.md](features/onboarding.md)).
- English and French; build configuration for ad IDs; CI workflow.

### Still not verified from M0

- **Permission prompts on a phone** (items 4 to 9 of the M0 checklist in [testing.md](testing.md#manual-verification-on-a-device)), including Android 14+ partial access, the most uncertain item.
- **CI result on GitHub**: the repository is private, so its status cannot be read from the development machine.
- **Release build**: `flutter build appbundle --release` has not been run locally.

## Known issues (all milestones)

- The splash screen and launcher icon were Flutter's defaults (done in the [visual refresh](visual-refresh.md)).
- Onboarding illustrations were Material icons (done in the [visual refresh](visual-refresh.md)).
- Release builds are signed with the debug key (planned for M12).
- The debug APK is about 200 MB (every CPU architecture and debug symbols); Google Play delivers split release bundles.

## Open questions

- **Google Play policy for `MANAGE_MEDIA`**: to confirm before the first release ([ADR 0006](decisions/0006-permissions.md)). The app already works without it.
