# Testing

How Clean Gallery is tested: test layers, commands, fakes and fixtures. Every milestone adds tests for what it builds; a milestone is not done until the suite passes.

Last updated: 2026-11-11 — Issue #19

## Commands

```sh
flutter test                                  # all tests
flutter test test/features/onboarding/        # one folder
flutter test --coverage                       # writes coverage/lcov.info
flutter analyze                               # lints
dart format --set-exit-if-changed lib test    # formatting
```

Run `dart run build_runner build` first if generated files are missing.

## Test layers

| Layer | Tool | Location | Covers |
| --- | --- | --- | --- |
| Unit | `flutter_test` | `test/core/`, `test/features/*/…_controller_test.dart` | Repositories, controllers, pure logic. |
| Widget | `flutter_test` | `test/features/*/…_screen_test.dart` | Screens rendered with fakes, user flows inside the app. |
| Architecture | `flutter_test` + `dart:io` | `test/architecture/` | Import rules between layers, forbidden permissions. |
| Analysis engine | `test` (pure Dart) | `test/analysis/` (from M3) | Algorithms on a fixture photo set. |
| Integration | `integration_test` | `integration_test/` (from M2) | Delete and trash flows on a device or emulator. |

## Fakes

Shared fakes live in [test/helpers/fakes.dart](../test/helpers/fakes.dart):

| Fake | Replaces | Behavior |
| --- | --- | --- |
| `inMemoryDatabase()` | `AppDatabase.open()` | Fresh SQLite database in memory per test. |
| `FakePermissionService` | `PermissionService` | Returns a configurable `MediaAccess`; counts requests. |
| `FakePlatformBridge` | `PlatformBridge` | Records calls; never touches Android. |
| `FakeMediaSource` | `MediaSource` | In-memory items and folders; records loaded ranges; every image is a 1 × 1 PNG. |
| `testItem(id, …)` | — | Builds a photo or video `MediaItem` with a given date. |

Fakes are injected by overriding providers in a `ProviderScope` or `ProviderContainer`. Prefer hand-written fakes for interfaces that are used in many tests; use `mocktail` for one-off interactions.

## Current coverage

| File | What it checks |
| --- | --- |
| [app_database_test.dart](../test/core/database/app_database_test.dart) | Schema version, migration 1 → 2 with a trashed item, later migrations up to 5 → 6 (user albums), enum storage, foreign keys, cascade delete (assets, user albums), settings repository. |
| [user_album_repository_test.dart](../test/core/database/user_album_repository_test.dart) | User albums: creating, adding (only new items counted), several albums per item, trash and missing items, removing, forgetting, cover, rename, delete and restore. |
| [user_albums_test.dart](../test/features/user_albums/user_albums_test.dart) | User albums in the app: My albums, name rules, adding from a selection and the viewer, *Already in it*, remove with Undo, rename, delete with Undo. |
| [onboarding_controller_test.dart](../test/features/onboarding/onboarding_controller_test.dart) | Permission flow for granted, limited and denied access; persistence of completion. |
| [onboarding_screen_test.dart](../test/features/onboarding/onboarding_screen_test.dart) | Privacy promise shown, full flow, skip, returning users skip onboarding. |
| [dependency_rules_test.dart](../test/architecture/dependency_rules_test.dart) | Pure-Dart engine and domain, no direct Android imports in features, no `MANAGE_EXTERNAL_STORAGE`. |
| [navigation_test.dart](../test/core/router/navigation_test.dart) | Five icon-only tabs, switching tabs, Stats content, 48 dp touch targets. |
| [timeline_test.dart](../test/domain/timeline_test.dart) | Day and month sections, grid rows, grouping by column count. |
| [media_providers_test.dart](../test/core/media/media_providers_test.dart) | First chunk then the rest from the index, reload in place without a loading state, column limits, duration format. |
| [best_picker_test.dart](../test/analysis/best_picker_test.dart) | Each best-pick rule in order, best item first. |
| [burst_test.dart](../test/analysis/burst_test.dart) | Burst names of Samsung and Google cameras, different bursts and folders, ordinary names. |
| [screenshot_test.dart](../test/analysis/screenshot_test.dart) | Screenshots by folder, name or PNG at the screen size; camera photos and other images are not. |
| [cleanup_selection_test.dart](../test/core/database/cleanup_selection_test.dart) | Old screenshots, large videos and blurry photos read from the index. |
| [image_quality_test.dart](../test/analysis/image_quality_test.dart) | Sharpness and brightness of sharp, recompressed, blurred, dark and flat images. |
| [swipe_session_test.dart](../test/features/swipe/swipe_session_test.dart) | Swipe sessions: order, the three actions, multi-level undo, resume, start over, source keys, months. |
| [swipe_flow_test.dart](../test/features/swipe/swipe_flow_test.dart) | Sort mode from the Stats tab: swipe, fling, short drag, buttons, undo, summary, resume. |
| [cleanup_flow_test.dart](../test/features/cleanup/cleanup_flow_test.dart) | Stats rows of the cleanup lists, Select all and move to trash, large video threshold, blurry photos measured and listed. |
| [duplicates_test.dart](../test/core/media/duplicates_test.dart) | Only size collisions hashed, exact groups, no re-read, filter by folder, trash and undo, changed file, favorite kept, burst groups, a burst saved twice. |
| [duplicates_flow_test.dart](../test/features/duplicates/duplicates_flow_test.dart) | Duplicates tile and count, screen, clean all with summary, keep every copy, open a photo full screen. |
| [perceptual_hash_test.dart](../test/analysis/perceptual_hash_test.dart) | Hamming distance, area resize; the same photo recompressed, resized, brightened, cropped stays close; 40 unrelated scenes stay apart (false positive regression). |
| [similarity_test.dart](../test/analysis/similarity_test.dart) | Multi-index search against brute force, union-find, strict and loose rules, aspect ratio, chains, ignored pairs, certain groups, presets, High groups a scene reframed minutes later (issue #19), confidence, a mixed photo set. |
| [duplicates_test.dart](../test/core/media/duplicates_test.dart) (period) and [similar_photos_test.dart](../test/core/media/similar_photos_test.dart) (period) | Items outside the duplicate period are neither hashed nor grouped; similar photos of the period only, every photo still measured, the period's first. |
| [steady_slider_test.dart](../test/core/widgets/steady_slider_test.dart) | The app's slider rounds to its steps within its range and is never a discrete (animated) Material slider. |
| [media_thumbnail_test.dart](../test/core/media/media_thumbnail_test.dart) | Thumbnail size steps; a thumbnail without a size asks for the size of its box; the sharp version only over a cached thumbnail too small. |
| [color_picker_test.dart](../test/features/editor/color_picker_test.dart) | Hex codes of the editor's color picker. |
| [similar_photos_test.dart](../test/core/media/similar_photos_test.dart) | Similar scan through the media source: groups, photos only, hashes kept, Not duplicates, changed file, new thresholds without re-reading, exact copies stay certain, folder filter. |
| [similar_flow_test.dart](../test/features/duplicates/similar_flow_test.dart) | Similar photos section, Not duplicates, Stats values and link to the duplicates screen. |
| [storage_summary_test.dart](../test/features/stats/storage_summary_test.dart) | Dashboard values by category, an item counted once (also across screenshots and large videos), the trash, an empty library. |
| [capture_date_test.dart](../test/analysis/capture_date_test.dart) | File name date patterns, rejected names, date-only names, resolution order. |
| [android_media_source_test.dart](../test/platform/android_media_source_test.dart) | When MediaStore's `DATE_TAKEN` counts as a metadata date. |
| [media_index_test.dart](../test/core/media/media_index_test.dart) | Capture dates resolved during a sync, rules version, sort by corrected or platform date; sync plan; first, unchanged and incremental syncs; analysis kept unless the file changed; platform version change; denied and limited access; merged calls; index filters, sorts, date range, folders and trash exclusion. |
| [library_test.dart](../test/features/library/library_test.dart) | Timeline headers, photo/video filters, empty, denied and limited states, Albums and folder pages, opening the viewer, pinch gesture, pull-to-refresh indexing new items. |
| [sort_filter_test.dart](../test/features/library/sort_filter_test.dart) | Date ranges and presets, plain rows, sort by name, date preset and chip removal, empty period, viewer order, per-tab state. |
| [fast_scroller_test.dart](../test/features/library/fast_scroller_test.dart) | Thumb visibility, drag jump with month bubble, size bubble, short lists, size formatting. |
| [viewer_test.dart](../test/features/viewer/viewer_test.dart) | Swipe both ways, pinch then pan without page change, double-tap back, top bar height. |
| [video_controls_test.dart](../test/features/viewer/video_controls_test.dart) | Video progress bar at the bottom, play button centered, portrait and landscape. |
| [trash_repository_test.dart](../test/core/database/trash_repository_test.dart) | Trash order and expiry, live ids, restore, forget, duplicates, days left. |
| [app_settings_test.dart](../test/core/settings/app_settings_test.dart) | Default, stored and invalid settings, similarity and cleanup settings; sort encoding; view keys. |
| [trash_flow_test.dart](../test/features/trash/trash_flow_test.dart) | Trash from the viewer with undo, Trash page, restore, delete for good, declined prompt, expiry offer, silent purge, Trash album count. |
| [selection_test.dart](../test/features/library/selection_test.dart) | Long press, tap, drag range, trash with undo, favorite, share, back. |
| [settings_screen_test.dart](../test/features/settings/settings_screen_test.dart) | Theme, language, default columns, corrected dates switch, sensitivity and advanced mode, permission statuses, sort saved and restored. |
| [about_screen_test.dart](../test/features/about/about_screen_test.dart) | Privacy policy link in Settings, About page (version, promise, links), licenses page, font licenses registered. |
| [accessibility_test.dart](../test/accessibility/accessibility_test.dart) | Flutter's accessibility guidelines (48 dp tap targets, labels on everything tappable, text contrast) on the five tabs, Trash, Search, Rituals, About, the photo and video viewer and the onboarding, in light and dark themes. |

App-level widget tests use `pumpTestApp` ([pump_app.dart](../test/helpers/pump_app.dart)): the whole app on a phone-sized screen (1080 × 2400 px at 3×) with all fakes, so tests see what a user would. They are declared with `testApp` instead of `testWidgets`: it unmounts the app at the end, even after a failure, and lets Drift close its stream queries (Drift closes them on a zero-length timer; without this step Flutter reports a pending timer and the run hangs).

Run the suite with a per-test timeout so a hang fails fast: `flutter test --timeout 60s`.

## Fixtures

The similar photo engine is tested against a synthetic photo set generated in memory by [photo_set.dart](../test/analysis/photo_set.dart) with the `image` package (dev dependency): seeded scenes (gradient, shapes, grain), and variants recompressed as JPEG, resized, brightened, cropped, or with the subject moved. No image file is stored in the repository and no personal photo is used. Exact duplicates and bursts are tested with fake hashes and file names through `FakeMediaSource`.

The scan runs hashing and grouping in isolates; app-level widget tests replace `analysisRunnerProvider` with an inline runner in `pumpTestApp`, since the fake clock of `testWidgets` cannot wait for an isolate. Unit tests (`ProviderContainer`) keep real isolates.

## Manual verification on a device

**Test speed and fluidity on a release build**, never on a debug build: debug builds run without ahead-of-time compilation and are several times slower. For the Galaxy A54:

```sh
flutter build apk --release --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Release builds are signed with the debug key until the product owner's upload key exists ([release.md](release.md#upload-key)); such builds install over a debug build and keep the app data. Once signed with the upload key, a release build no longer installs over a debug build: uninstall first, which clears the app's data.

Automated tests use fakes and never touch Android. The items below can only be checked on a real phone or a working emulator. Each milestone adds its own items; tick them in the pull request or commit that verifies them, with the device and Android version used.

Install the debug build with:

```sh
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

To replay onboarding, clear the app data: `adb shell pm clear com.bichoumac.clean_gallery`.

### M0 — not yet verified on a device

| # | Check | Android | Expected |
| --- | --- | --- | --- |
| 1 | First launch shows the onboarding privacy page | any | "Your photos never leave your device." in the system language (EN or FR). |
| 2 | Brand palette and Manrope | any | The palette, accent and typefaces of the theme at the right weights ([design.md](design.md)). |
| 3 | Dark mode | any | Switching the system theme switches the app theme. |
| 4 | *Allow access*, choose "Allow all" | 13+ | Photos and videos prompts, then the GPS metadata prompt. Page shows no warning. |
| 5 | *Allow access* on Android 11–12 | 11, 12 | One storage prompt, then the GPS metadata prompt. |
| 6 | *Allow access*, choose "Select photos" | 14+ | "Only some of your media is shared" with *Allow access to all*, which opens the app's settings. **Most uncertain point**: depends on `permission_handler` reporting `limited`. |
| 7 | *Allow access*, choose "Don't allow" | any | Denied message and *Open settings*; *Next* still works; no GPS prompt. |
| 8 | *Allow media management* | 12+ | Opens the system "Media management" screen for Clean Gallery. |
| 9 | *Allow media management* | 11 | Nothing happens, no crash. |
| 10 | *Get started* / *Skip* | any | Opens the five-tab shell (Photos, Videos, Albums, Stats, Settings): small floating bar, icons only; Stats shows the reclaimable space card with "—". |
| 15 | Navigation bar | any | Long-press shows each tab's name; content scrolls under the blurred bar; nothing hidden behind it. |
| 11 | Relaunch the app | any | Goes straight to the tabs, onboarding is not shown again. |
| 12 | Kill the app mid-onboarding, relaunch | any | Onboarding restarts from the first page. |
| 13 | Rotate the screen, change font size to the largest | any | No overflow or clipped text on onboarding pages. |
| 14 | TalkBack on onboarding | any | Buttons and texts are read; the illustration is skipped. |

### Issue #19 and blurry thumbnails — to verify on a device

Built on branch `fix-issue-19` on 2026-11-11. **Confirmed on the phone by the product owner on 2026-11-11** ("tout est ok"), except item 7: thumbnails loaded more slowly than before. Measured and fixed the same day (sharp versions in a lane of their own, [library.md](features/library.md#thumbnail-size)); items 14 to 17 check the fix and the color picker.

| # | Do | Expected |
| --- | --- | --- |
| 1 | Editor → Ajuster → Luminosité at 0: drag the thumb right, then from 0 to the left | The thumb follows the finger from the first movement, both ways, without tapping first. |
| 2 | Same slider, and Redresser, Intensité of a filter: drag fast back and forth | The thumb stays under the finger, without lagging then catching up. |
| 3 | Settings → Corbeille retention, and the three sliders of *Mode avancé*; the video slider | Same: immediate and steady. |
| 4 | Settings → Analyse | *Photos similaires : seuil de tolérance*; the text under Faible / Moyenne / Élevée changes with the one picked and says what it groups. |
| 5 | Pick *Élevée*, open Doublons → Photos similaires | Shots of one scene taken a few minutes apart, slightly reframed, are grouped. Note any group of unrelated photos. |
| 6 | *Mode avancé* | Starts at 10 / 64, 18 / 64 and *10 minutes*; the last slider goes from 5 secondes to 30 minutes. |
| 7 | Camera grid at 4 columns, then pinch to 3 and 2 | Thumbnails sharp at every size; at 2 columns they may appear a moment later than before. |
| 8 | Albums tab (covers of the mosaic), a memory card | Covers sharp, no longer soft or pixelated. |
| 9 | Scroll the grid fast | As smooth as before; no run of missing thumbnails. |
| 10 | Settings → Analyse → *Période analysée*: *Du* a date a few months ago | The date shows in the accent with a cross; *Toute la bibliothèque* appears; the analysis runs again. |
| 11 | Stats, the Duplicates tile of Camera, Doublons | Only groups of photos taken since that date; counts match. Doublons shows *Période : <date> – aujourd'hui* at the top. |
| 12 | Open a photo of an old duplicate pair | No group strip in the viewer for it. |
| 13 | The chip's cross in Doublons (or *Toute la bibliothèque*) | Every group is back, without reading the whole library again. |
| 14 | Camera grid at 4 columns, scroll fast | Thumbnails as quick as in 1.0.0. |
| 15 | Pinch to 2 columns, Albums covers, a memory card | A thumbnail shows at once, then turns sharp a moment later with a short fade. |
| 16 | Editor → Dessiner: scroll the color row, tap the rainbow swatch | The picker opens; the square, the hue bar and a typed code (e.g. `#12AB9F`) change the new color; *Choisir* applies it and the rainbow swatch shows it framed. |
| 17 | Texte: the same for the text color and its background | Same picker; *Aucun* still removes the background. |

### M12 — release preparation, to verify on a device

Built on branch `m12-release` on 2026-11-08. **Confirmed on the phone by the product owner on 2026-11-09** as a whole ("ça marche bien"), not item by item.

| # | Do | Expected |
| --- | --- | --- |
| 1 | Settings, scroll to the end | An *À propos* section with *Politique de confidentialité* and *À propos de Clean Gallery*. |
| 2 | Tap *Politique de confidentialité* | The browser opens the policy on GitHub (a 404 page while the repository is private). |
| 3 | Tap *À propos de Clean Gallery* | The rosace, *Clean Gallery*, *Version 1.0.0*, the promise and the GPL line; the page slides in like the others. |
| 4 | Tap *Code source*, *Signaler un problème*, *Licence*, the OpenStreetMap credit | Each opens the right page in the browser. |
| 5 | *Bibliothèques open source* | Flutter's licenses page with the app's name, version and rosace; *Manrope* and *Bricolage Grotesque* are in the list. |
| 6 | Onboarding (clear the app's storage first, or skip) | The first page says *Clean Gallery trie et nettoie vos photos sur votre téléphone…* instead of *fonctionne entièrement hors ligne*. |
| 7 | With TalkBack on, in the Camera grid: double-tap and hold a thumbnail | The photo is selected and the selection bar appears; TalkBack says *sélectionner* as the long-press action. |
| 8 | With TalkBack on, open a photo and a video | TalkBack reads *Photo, <date>* or *Vidéo, <durée>, <date>* and offers to show or hide the controls; double-tap toggles them. The video's play and seek controls stay reachable. |

Release signing was checked on the development machine with a throwaway key: the release APK is signed with it, `apksigner` shows its certificate; without a key, Gradle warns and signs with the debug key.

### Video gestures — to verify on a device

All items confirmed by the product owner on 2026-11-08 on the Galaxy A54, after two fixes (speed slide, instant tap). Open a video in the viewer.

1. Slide up then down on the left half: a pill shows *Luminosité* and its level; the screen follows. Leave the video: the brightness goes back to the system's.
2. Slide up then down on the right half: *Volume* follows, the phone's volume changes, no Samsung volume panel.
3. Double tap on the right: *+10 s*, the video jumps; tap once more quickly: *+20 s*. Same on the left with *−10 s*, never before the start.
4. In the top quarter of the video, slide right then left: *Vitesse 1,25×*, *1,5×*… up to *2×* and down to *0,25×*; the video plays at that speed.
5. Lower on the video, slide left or right: moves to the next or previous item as before.
6. A single tap shows and hides the controls at once, without delay.
7. The progress bar can be dragged without touching the buttons below it.

### Page transitions — to verify on a device

First run on 2026-11-08 on the Galaxy A54: 1 and 7 OK; pages had no transition (2, 3, 4), the photo landed off-center (6), the theme change stuttered (8); all three fixed after, to check again. Install a profile or release build: debug builds are too slow to judge motion. First check that *Paramètres → Accessibilité → Améliorations de la visibilité → Supprimer les animations* is off, or every transition is instant on purpose. **All items confirmed on the phone by the product owner on 2026-11-08** after the fixes.

1. Tap each tab of the bar in turn, then back: the new tab slides in from the side of its button, the old one leaves on the other side, smoothly; each tab keeps its scroll position.
2. Albums: tap *Favoris*, *Carte*, *Diaporamas*, *Corbeille*, *Tous les médias* and an album cover: each page grows out of the tile, its corners rounding into the screen's; back shrinks it into the same tile.
3. Stats: tap *Anciennes captures d'écran*, *Photos similaires* and *Mode tri*: same growth from the tile.
4. Settings → *Rituels*, a search, the editor: the page slides in from the right; the page below shrinks a little and darkens; back plays it in reverse.
5. Back gesture from the screen's edge on an album page, slowly: the page follows the finger. Let go early: it comes back. Swipe further: it leaves.
6. Tap a portrait photo, then a landscape one, in a grid and in search results with the keyboard open: the thumbnail opens into the whole photo with a slight spring, without the picture jumping at the start or the end. Pull it down: it lands back in its square.
7. During a transition, tap fast on the bar or the back button: no freeze, no blank page, no double page.
8. Turn *Supprimer les animations* on: tabs and pages change at once.
9. Light and dark themes: the darkening of the page below looks right in both.
10. Settings → *Thème*: tap *Sombre*, then *Clair*: the new theme spreads in a circle from the finger, smoothly.

### Open source without ads — to verify on a device

Ads and the purchase were removed on 2026-11-08 ([ADR 0032](decisions/0032-open-source-without-ads.md)). All items confirmed on the phone by the product owner on 2026-11-08.

1. Install over the previous build (no uninstall): the app opens on the tabs, albums, settings and slideshows as before.
2. Albums: no banner and no *Remove ads* link; the last album scrolls fully into view above the bar.
3. Stats: no ad card; the Trash tile follows the other tiles.
4. A slideshow from an album starts right after *Start*, with no ad.
5. Settings: no *Annonces* section.
6. Delete more than 500 MB for good from the trash: no offer appears.

### Visual refresh — to verify on a device

The [visual refresh](visual-refresh.md) is built. First pass on the phone on 2026-11-04: the product owner reported "tout me paraît bien" as a whole, apart from the map (slow to load, some thumbnails missing), without going through the list item by item. So no item below is individually confirmed.

| # | Do | Expected |
| --- | --- | --- |
| 1 | Home screen | A citron icon with a rosace, seven petals tone on tone and one dark, clear in the launcher's shape. |
| 2 | Turn on themed icons | The icon follows the system color, with the dark petal still standing out. |
| 3 | Launch in light, then dark | The launch screen matches the theme; no flash of citron over the whole screen. |
| 4 | Camera tab in dark | Black neutral background behind the grid; citron selected tab; content visible through the bar. |
| 5 | Camera tab in light | White behind the grid, no cream. |
| 6 | Stats tab | Citron card with the number and a gauge whose lit petals match the share; every category is there. |
| 7 | Clean until nothing is left | The gauge goes down petal by petal, to none. |
| 8 | Albums tab | Mosaic with *All media*, Favorites, Map, Slideshows, Trash; then *My albums* and *Folders*. |
| 9 | Sort mode, drag a card right, then left | *Garder* in citron, *Corbeille* in red, easy to tell apart. |
| 10 | Sort to the end | Citron screen, complete rosace, the counts and the three actions. |
| 11 | Open a video | White translucent play button, white slider, no citron. |
| 12 | Photo at 1× zoom, pull down, release early | It springs back. |
| 13 | Pull down further | It returns to its thumbnail in the grid. |
| 14 | Zoomed photo, pull down | It pans; the viewer does not close. |
| 15 | Info panel, pull down | The panel closes, not the viewer. |
| 16 | Empty trash | The rosace with one citron petal, *Rien à jeter*, the retention set in Settings. |
| 17 | Memory notification | The rosace in the status bar. |
| 18 | System animations off | No animation, nothing blocked. |
| 19 | Largest system text size | Stats number and titles fit, nothing clipped. |
| 20 | TalkBack on the Stats card | The share is read as a sentence. |
| 21 | Editor, text | The selected text's frame and the color row show the new citron. |

### M9 — slideshows and memories, to verify on a device

From a release build of branch `m9-slideshows-memories`. The first launch migrates the database to schema version 7 (four new tables; nothing is read again). For a memory to show, the camera needs at least 6 good photos taken on today's date, or 8 during this week (Monday to Sunday), one year ago or more.

| # | Check | Expected |
| --- | --- | --- |
| 95 | Open a folder (e.g. Camera) from the Albums tab | A **Diaporama** button (▶ in a frame) in the title, before the magnifier. |
| 96 | Tap it | A sheet: *Durée par photo* 3 / 5 / 8 s, *Transition* Fondu / Zoom lent, *Ordre* Par date / Aléatoire, *Inclure les vidéos*, *Sauter les doublons et les photos floues*, *Musique* (Aucune, *Choisir un morceau sur le téléphone*, a line saying bundled music comes soon). |
| 97 | **Lancer** with 3 s and *Zoom lent* | Full screen, black, no status or navigation bar; oldest photo first; each photo slowly zooms in or out and fades into the next. The screen does not turn off after 30 s. |
| 98 | Tap the screen | Close, title, *Enregistrer*, "3 sur 24", previous, pause, next; they hide after 3 s. *Pause* stops the photo and the zoom; *Lire* continues. |
| 99 | A folder with videos, *Inclure les vidéos* on | Videos play without sound, at most 10 s, then the next item. Off: no video. |
| 100 | Options → *Choisir un morceau sur le téléphone* → pick an MP3 | The system file picker opens (no permission asked); the track's name is chosen in the list; it plays in a loop, pauses with the slideshow, and fades out at the end. |
| 101 | Delete or move that MP3 with the file manager, start a slideshow with it | *La musique ne peut pas être lue…*; the slideshow plays without music. |
| 102 | Let a slideshow end | *Revoir*, *Enregistrer*, *Fermer*. **Enregistrer** → title (the folder's name proposed) → *Enregistrer*: *Enregistré dans Albums → Diaporamas*; *Enregistrer* is no longer offered. |
| 103 | Albums tab → **Diaporamas** | A *Diaporama* tile, then the saved slideshow (cover, count). A tap plays it with its own options and music, in the same order. |
| 104 | Long press the saved slideshow → *Renommer*, then *Supprimer* → *Annuler* | Renamed; deleted with *Diaporama supprimé…*, brought back by *Annuler*. The photos never move. |
| 105 | Camera: select 3 photos → ⋮ → **Diaporama** → *Lancer* | Only those 3 photos play. |
| 106 | Albums → Diaporamas → **Diaporama** | The sheet starts with an **Album** list (*Tous les médias*, Favoris, your albums, then the folders; typing filters it) and a *Période* (Tout, 7 derniers jours, …, Personnalisée). Pick a folder and *Tout*: only that folder plays, titled "<dossier> · Tout". |
| 107 | A user album page, search results, an area of the map | The same *Diaporama* button, playing what the page shows (date range included). |
| 108 | Camera tab, with photos from a year ago this week or today | A **souvenir** card at the top: cover, *Cette semaine, il y a 1 an* or *Ce jour-là, il y a 1 an*, dates and number of photos. A tap plays it (blurry photos and duplicates left out). |
| 109 | ✕ on the card, then *Annuler* | *Souvenir masqué*; the card leaves and comes back. ✕ again: it stays hidden after a relaunch. |
| 110 | Albums → Diaporamas → **Souvenirs** | Every memory found and not hidden; tap plays, ✕ hides. |
| 111 | Réglages → **Diaporamas et souvenirs** → *Notification* on | Android asks to allow notifications (first time only). Then the day and time (default *Dimanche*, 19:00). *Désactivés* hides the memory card. |
| 112 | Réglages → **Rituels** → *Nouveau rituel*: *Les photos de la semaine*, *Chaque semaine*, today, in 3 minutes → *Enregistrer* | The ritual is listed as "Chaque mardi à …". Within a few minutes of that time (Android may be late), a notification *Votre diaporama est prêt — Les photos de la semaine*; a tap opens the app and plays the last seven days' photos. |
| 113 | Restart the phone before the time of a ritual | The notification still comes (set again after the reboot). |
| 114 | A ritual's ⋮ → *Lire maintenant*; its switch off; *Supprimer* → *Annuler* | Plays at once; no notification while off; deleted and restored. |
| 115 | Refuse the notification permission (or turn it off in the system settings), then turn on a ritual | *Les notifications sont désactivées…* with *Réglages*; the memory card still shows in the app. |

Result on the Galaxy A54: after the first build (commit `654e04f`, 2026-11-03), the product owner found it "très cool" and asked to pick the album of a custom slideshow (item 106 updated). After installing commit `102c3b2` (album choice, and the fix for closing a slideshow without music), the product owner reported on 2026-11-04: "ça marche bien". The report was overall, not item by item.

### M8 — user albums, to verify on a device

From a release build of branch `specs-albums-slideshows-people`. The first launch migrates the database to schema version 6 (two new tables; nothing is read again).

| # | Check | Expected |
| --- | --- | --- |
| 84 | Albums tab, scroll below Corbeille | **Mes albums**, one line ("Rassemblez photos et vidéos sans les déplacer…") and a **Nouvel album** button; then the folders as before. |
| 85 | **Nouvel album**, *Créer* with an empty name, then type `Vacances` → *Créer* | *Saisissez un nom* under the field; then the empty album opens, explaining *Plus → Ajouter à un album*. Back: *Mes albums* shows a *Nouvel album* tile and *Vacances*, 0 éléments. |
| 86 | Camera: long press two photos → ⋮ (*Plus*) → **Ajouter à un album** → *Vacances* | The menu also holds *Tout sélectionner*. Snackbar *2 éléments ajoutés à Vacances*, **Ouvrir** opens the album with the two photos; its tile shows the newest as cover and *2 éléments*. |
| 87 | The same two photos again → *Ajouter à un album* | *Vacances* reads *Déjà dedans*; tapping it: *Déjà dans Vacances*. With a third photo selected: *2 déjà dedans*, then *Ajouté à Vacances*. |
| 88 | Viewer → **Ajouter à un album** (new button of the bottom bar) → *Nouvel album* `Famille` | *Ajouté à Famille*; the album exists with that photo. |
| 89 | In *Vacances*: select one photo → ⋮ → **Utiliser comme couverture** | *Couverture modifiée*; the album's tile uses it. |
| 90 | In *Vacances*: select a photo → ⋮ → **Retirer de l'album**, then *Annuler* | The photo leaves the album and comes back; it is still in Camera and in its folder all along. |
| 91 | Album ⋮ (*Options de l'album*) → **Renommer** `Famille` (the other album's name), then `Été 2026` | *Un album porte déjà ce nom*; then the title and the tile read *Été 2026*. |
| 92 | Album ⋮ → **Supprimer l'album** | *Supprimer « Été 2026 » ?* says its items stay on the phone; after *Supprimer*, the page closes, *Album supprimé…* with *Annuler*; every photo is still in Camera and in the system gallery (Google Photos / Samsung Gallery). *Annuler* brings the album back with its photos and cover. |
| 93 | Move a photo of an album to the trash, then restore it | It leaves the album (count −1), then comes back. |
| 94 | The system gallery app, and the phone's file manager | No new folder, no copy: the albums exist only in Clean Gallery. |

Result on the Galaxy A54, reported by the product owner on 2026-11-01 after installing commit `c1b116f` (snackbars with a button closing by themselves): "ça marche". Every M8 item (84 to 94) is confirmed.

### M7 — search, to verify on a device

From a release build of branch `m7-search`.

| # | Check | Expected |
| --- | --- | --- |
| 71 | Camera, Videos and Albums tabs | A magnifier next to the title (Camera, Videos: before the sort button). |
| 72 | Tap it | *Rechercher*: keyboard up in a *Nom de fichier* field; chips Photos, Vidéos, Captures d'écran, Favoris, Dossier, Zone on two lines; below, *Résultats* with the number of items, every photo and video. |
| 73 | Type part of a file name (e.g. `IMG_2026`, or `screenshot`) | After a short pause, only matching items; the count follows; ✕ empties the field and shows everything. |
| 74 | **Vidéos**, then Vidéos again; **Captures d'écran** | Only videos, then everything again; only screenshots. |
| 75 | **Favoris** with Photos | Only favorite photos. |
| 76 | **Dossier** → pick *WhatsApp Images* (or another) | The chip shows the folder's name, only its items; the chip's ✕ removes it. |
| 77 | **Zone** → move the map onto a city → **Rechercher dans cette zone** | Back to the search, chip *Zone sur la carte*, only items taken there; tapping the chip reopens the map on that area. |
| 78 | Results' sort button → *Cette année*, then change a criterion; open a result | The date range and its chip stay; the viewer swipes through the results only. |

Results on the Galaxy A54, reported by the product owner on 2026-10-30 after installing commit `d55b708`: everything works, but the search looked through every item instead of the tab it was opened from. Changed: the search is limited to the timeline it is opened from.

| # | Check | Expected |
| --- | --- | --- |
| 79 | Camera tab → magnifier | *Dans Appareil photo*: only the camera's photos; no Photos / Vidéos / Captures chips, no Dossier chip. A name finds only camera photos. |
| 80 | Videos tab → magnifier | *Dans Vidéos*: only videos; no type chips; Dossier, Favoris and Zone remain. |
| 81 | Albums → a folder (e.g. WhatsApp Images) → magnifier at the top right | *Dans WhatsApp Images*: only that folder's items; no Dossier chip. Albums → Favoris → magnifier: only favorites, no Favoris chip. |
| 82 | Sort the results by name, go back to the tab | The tab keeps its own order. Albums tab → magnifier: everything, every chip. |

Results on the Galaxy A54, reported by the product owner on 2026-10-30 after installing commit `6f858a1`: items 79 to 82 all OK; a search by date asked for.

| # | Check | Expected |
| --- | --- | --- |
| 83 | Search → **Dates** → *Cette année*, then **Dates** → *Personnalisée…* and pick two days | The sheet closes; the chip reads *Cette année*, then the two dates; only items of that period; the chip's ✕ shows all dates again. The period combines with a name and the other chips. |

Result on the Galaxy A54, reported by the product owner on 2026-10-30 after installing commit `13b0e3b`: item 83 OK. Every M7 item (71 to 83) is confirmed.

### M6 — viewer and editing, to verify on a device

Part 1, info panel. Install over M5 (`adb install -r`).

| # | Check | Expected |
| --- | --- | --- |
| 1 | Open a photo taken with the phone, tap ⓘ (Details) | A panel slides up; the photo shows blurred through it. Date with *From the photo's metadata (EXIF)*, name, path, resolution with megapixels, size. |
| 2 | Same panel, below | Camera (e.g. *samsung Galaxy A54 5G*), then tiles ISO, Aperture, Shutter speed, Focal length with its 35 mm equivalent. |
| 3 | A photo taken with location on | Coordinates under *Location · tap to open in a map app*; tapping them opens the map app on the right place; the copy button shows a check and the coordinates paste elsewhere. |
| 4 | A WhatsApp image or a screenshot | *From the file name* or *File date*; *No camera information in this file.* |
| 5 | A video | Duration; its location if the camera saved one; no camera tiles. |
| 6 | Swipe the panel down, tap above it, Back | Each closes it; the viewer stays on the same photo. |
| 7 | Largest font size | The panel scrolls to its last row, above the navigation bar; nothing is cut off. |

Hazy photos (M5 follow-up). The first launch migrates the database (schema version 4) and analyses again only the photos that were below the blur threshold: a few minutes at most.

| # | Check | Expected |
| --- | --- | --- |
| 8 | Once the analysis is done, Stats → **Blurry photos** | The hazy night photos with lights are gone; the photos really out of focus are still there. |
| 9 | Duplicates, a group with a hazy photo | No *Blurry* label under it. |
| 10 | A photo, ⓘ, last row | *S … · N … · B … · C …* and *Quality: …*; *offered as blurry* only when the photo is in the Blurry photos list. |

Stacks in the timelines (product owner's request, built before the editor). Install over part 1.

| # | Check | Expected |
| --- | --- | --- |
| 11 | Photos tab, a day with a burst or several shots of the same scene | One thumbnail with an accent badge (e.g. ⧉ 4) instead of the series; the cover is the photo marked *Best* in Duplicates. |
| 12 | Tap the stack | It unfolds in place; an accent line under each photo; a round button on the cover. |
| 13 | Tap a photo of the unfolded stack, then swipe in the viewer | It opens on that photo; swiping goes through every photo, stacked ones included. |
| 14 | Back, tap the round button | The stack folds again. |
| 15 | Long-press a folded stack | *4 selected* (all its photos); a tap on it deselects them. |
| 16 | Sort by size; then Stats → Old screenshots | No stacks: every item shows. |
| 17 | Photos taken between two shots of one scene, or a series around midnight | Separate thumbnails where the series is interrupted; no stack spans two days. |

Map (from M7). The first launch migrates the database (schema version 5) and reads where every photo was taken, in the background: a few minutes, to report.

| # | Check | Expected |
| --- | --- | --- |
| 18 | Albums tab | A **Map** tile with a count and the newest located photo. |
| 19 | Tap it | The map, fitted to all the places; thumbnails with accent counts; *© OpenStreetMap contributors* in the corner. |
| 20 | Pinch to zoom in on a city, then a street | Clusters split into smaller ones, then single photos. |
| 21 | Tap a cluster | *In this area*: only photos taken there; opening one and swiping stays in that area. |
| 22 | Back, tap a single photo | The viewer on that photo. |
| 23 | A photo with a location, ⓘ | A small map with an accent dot under the coordinates; tapping it opens the map there. |
| 24 | Dark mode, then airplane mode | Dark tiles; offline, tiles already seen still show, markers too. |
| 25 | Settings → Android → Clean Gallery → Permissions: remove photo location, back to the map | A card asks to allow it; *Allow* brings the markers back. |

Group strip in the viewer.

| # | Check | Expected |
| --- | --- | --- |
| 26 | Open a photo of a burst or of identical copies | At the bottom: *N doublons · toucher pour comparer*, the thumbnails, the first with an accent *Meilleure* pill, the photo shown framed in the accent color; *Corbeille* and *Garder* buttons. |
| 27 | Swipe the thumbnails sideways, tap one | The row scrolls; the viewer shows the tapped photo. |
| 28 | **Corbeille** | The photo goes to the trash, the next one of the group shows; its thumbnail stays dimmed with a bin; an Undo button appears. |
| 29 | Undo, then tap a dimmed thumbnail after another Corbeille | Each brings the photo back and shows it. |
| 30 | **Garder** | An accent check on the thumbnail; the next photo to sort shows. |
| 31 | A photo outside any group; a video; tap the photo | No strip on the first two; the strip hides and shows with the top bar. |

Info panel and sorts by duplicates (after the results below).

| # | Check | Expected |
| --- | --- | --- |
| 32 | A photo, ⓘ | The photo shows more clearly through the panel; the text stays readable. |
| 33 | Panel open, at the top of its content, pull it down | It follows the finger and closes; a short pull lets it slide back. Scrolled down, pulling down scrolls the content first. |
| 34 | Duplicates screen, sort button (top right) → *Plus de doublons d'abord* | The groups with the most photos come first. |
| 35 | Albums → All media → sort → *Doublons* | The largest groups first, each group's photos together, photos without duplicates at the end. |
| 36 | Albums tab, sort button next to *Dossiers* → *Doublons* | Folders with the most duplicates first, each reading "N éléments · M doublons". |

Results on the Galaxy A54, reported by the product owner on 2026-10-28 after installing commit `6c2fe5c`: "everything works" (items 32 to 36).

Part 2, the editor (no saving yet).

| # | Check | Expected |
| --- | --- | --- |
| 37 | Open a photo; a video | A sliders icon (*Modifier*) in the photo's top bar; none on the video. |
| 38 | Tap it | The editor, dark: the photo with a crop frame, accent corners, thirds lines; *Recadrer* and *Réglages* at the bottom. |
| 39 | Drag a corner, then inside the frame | The frame resizes, then moves; it never leaves the photo nor gets tiny. |
| 40 | *1:1*, then *16:9*; drag a corner | A square, then a wide frame, centered; the corner keeps the shape. |
| 41 | *Pivoter* four times; *Retourner* | The photo turns a quarter each time and comes back; it is mirrored. |
| 42 | *Réglages*: each chip, move the slider | The preview follows the finger smoothly; Saturation -100 is black and white; a dot marks the chips in use. |
| 43 | *Réinitialiser* | Everything back as it was. |
| 44 | Change something, then ✕ or Back | *Abandonner les modifications ?*; *Continuer* stays, *Abandonner* closes. Without changes, ✕ closes at once. The photo itself is never changed. |

First editor test on the Galaxy A54, reported by the product owner on 2026-10-28: sliders slow to start and to follow a fast finger, no way to save; asked for a pencil and for the favorite and edit buttons at the bottom. All four done on 2026-10-29:

| # | Check | Expected |
| --- | --- | --- |
| 45 | Open a photo | Share, favorite, edit, details and trash in a bar at the bottom; back, date and name at the top. |
| 46 | A video; a photo of a duplicate group | The progress bar sits above the action bar; the group strip too. |
| 47 | Editor → *Réglages*, move a slider fast, back and forth | The preview follows at once, from the first move. |
| 48 | *Dessiner*: pick a color and a width, draw; *Annuler* | Lines follow the finger; Undo removes the last one. Then rotate in *Recadrer*: the drawing turns with the photo. |
| 49 | Crop, adjust and draw, then **Enregistrer → Enregistrer une copie** | The editor closes, *Copie enregistrée*, the viewer shows the new photo: same crop, colors and drawing as the preview, sharp. The original is still there next to it. |
| 50 | The copy, ⓘ | Same date and camera as the original; its location if the original had one. |
| 51 | Another photo, **Remplacer l'originale** | *Photo remplacée ; l'originale est dans la corbeille*; the original is in Albums → Corbeille and can be restored. |
| 52 | A photo taken in portrait | The copy is upright, not on its side. |

Items 45 to 52 were installed on 2026-10-29 but not reported: the product owner asked for the next features first. They are tested with these, from the build installed on 2026-10-29 with the document scanner (commit "Document scanner; editor docs").

| # | Check | Expected |
| --- | --- | --- |
| 53 | Editor → Crop: **Straighten** slider | The photo turns by tenths of a degree, no empty corner; tapping the value returns to 0°. |
| 54 | Adjust → **Améliorer** on a dull or dark photo | Contrast and Brightness (and Saturation 10) set at once; the photo livelier; the sliders can refine it. On a photo already contrasted, almost nothing changes. |
| 55 | Adjust → **Vignettage** at 50, then -50 | Darker edges, then lighter edges, around the crop. |
| 56 | Hold the **Avant/Après** icon (top bar) | The original while held, the edit when released. |
| 57 | Draw → **Flou**, paint over a face; **Pixels** over a plate | Blurred, then large squares, only under the finger. **First test (2026-10-29): the whole photo was blurred/pixelated**; fixed the same day (clip instead of a blend mask), to test again. |
| 58 | **Texte** → Ajouter un texte, type two lines, OK | Centered on the photo, framed in the accent color. |
| 59 | Change font, Gras, size, color, background color; drag the text; double-tap it | Each applies at once; it follows the finger; double-tap opens its words. |
| 60 | Save a copy with straighten, Enhance, vignette, blur and a text | The saved photo matches the preview exactly, sharp, upright; text crisp. |
| 61 | Viewer, top bar: **Scanner un document** on a photo of a sheet on a table | Accent outline on the page's corners (*Page trouvée*); else the corners 8 % in. |
| 62 | Drag a corner; **Suivant** | The handle follows; the page flattened, straight. |
| 63 | **Gris**, **Noir et blanc**, back to **Couleur**; Back | Gray page; white paper and black text, no shadow; Back returns to the corners. |
| 64 | **Enregistrer** | *Scan enregistré*, the viewer shows the page; the original is still there. |

Filters (follow-up to M6, branch `m6-filters`), from a release build:

| # | Check | Expected |
| --- | --- | --- |
| 65 | Editor → **Filtres** (second icon) | A row of thumbnails of the cropped photo: Aucun, N&B, Sépia, Vintage, Chaud, Froid, Éclatant, Délavé, Dramatique, Noir, Doux; *Aucun* framed in the accent color; no slider. |
| 66 | Tap each thumbnail | The photo takes that look at once; its thumbnail framed in the accent color; an **Intensité** slider at 100 appears. |
| 67 | Move **Intensité** to 0, then 50 | At 0 the photo is unchanged; at 50 halfway; the slider follows the finger smoothly. |
| 68 | A filter, then **Réglages** → Luminosité or Chaleur | The slider refines the filtered photo (e.g. a warm tone on N&B). |
| 69 | Hold **Avant/Après**; then **Réinitialiser** | The original while held; Reset removes the filter too. |
| 70 | Save a copy with a filter at 60 and a crop | The saved photo matches the preview. |

Results on the Galaxy A54, reported by the product owner on 2026-10-30 after installing commit `798d4ff`: items 65 to 70 all OK.

Results on the Galaxy A54, reported by the product owner on 2026-10-29: blur and pixelate covered the whole photo (item 57); after the fix (commit `2090792`), "everything works" (items 45 to 64).

Results on the Galaxy A54, reported by the product owner on 2026-10-28 after installing commit `369e8b8`: stacks, map and group strip, "everything works" (items 11 to 31). The time taken by the first reading of locations was not reported.

Part 1 results on the Galaxy A54, reported by the product owner on 2026-10-27: first test, the end of the panel was hidden (fixed: room above the navigation bar, 90 % high) and the coordinates were not clickable (fixed: they open the map app). Second test, with the hazy photo rule: all good; the product owner read the temporary measures and set the hazy threshold at 150. Item 10 added afterwards, at the product owner's request; not seen on the device yet.

### M5 — cleanup, to verify on a device

Part 1, cleanup lists. Install over the M4 version (`adb install -r`, do not uninstall). The first launch describes every item again (index rules version 3): a few seconds, no thumbnails read.

| # | Check | Expected |
| --- | --- | --- |
| 1 | Stats tab, scroll to the second card | **Old screenshots** and **Large videos** with a count and a size; **Blurry photos** still *Coming soon*. The accent card's total grew by about those sizes. |
| 2 | Tap **Old screenshots** | Title, *Taken more than 30 days ago*, *N items · size*; only screenshots, none from the last 30 days. Report any photo that is not a screenshot. |
| 3 | Long-press one, then **Select all** (first icon of the bar) | Every item selected; the icon disappears. |
| 4 | **Move to trash**, then *Undo* | The list empties, then everything comes back. |
| 5 | Back, **Large videos** | *100 MB or more, largest first*; the largest video on top. |
| 6 | Settings → **Cleanup**: 7 d, then 500 MB; back to Stats | The screenshot row grows, the large video row shrinks; back to 30 d and 100 MB. |

Part 1 results on the Galaxy A54, reported by the product owner on 2026-10-27: all six items confirmed ("all good").

Part 2, blurry and dark photos. Install over part 1. The first launch migrates the database (schema version 3) and starts a full analysis: every photo is read again once (about 25 minutes for 20,000 photos).

| # | Check | Expected |
| --- | --- | --- |
| 1 | Use the app while the analysis runs; note how long it takes | Fluid; "Analyzing: N of M items" grows; about as fast as the M4 analysis (around 860 photos a minute). |
| 2 | Stats → **Blurry photos**, during and after the analysis | The row and the list fill in as photos are analysed. |
| 3 | Look through the list | Mostly out-of-focus, shaken or very dark photos. **Report sharp photos in the list** (false positives, e.g. sky, fog, a plain wall) and **blurry photos you know of that are missing**. |
| 4 | Duplicates → **Similar photos** and **Bursts** | Same groups as before, or nearly; in a group of close shots, the photo marked **Best** is the sharpest one. |
| 5 | Select some blurry photos, **Move to trash**, *Undo* | As in the other lists. |

Part 3, sort mode (swipe), and the *Blurry* label. Same install as part 2 if built together.

| # | Check | Expected |
| --- | --- | --- |
| 1 | Stats → **Sort mode** | The sources page: help text, *All photos*, *Blurry photos*, *Old screenshots*, then months and folders with their counts. |
| 2 | **All photos** | Full screen, oldest photo first, "0 / N" and an empty bar; *Undo* greyed out. |
| 3 | Swipe a card left, then one right | A *TRASH* / *KEEP* stamp while dragging; the card flies away; "2 / N". The first one is in Albums → Trash. |
| 4 | A short drag, released | The card springs back. |
| 5 | The three buttons (bin, heart, check) | Same as swiping; the heart asks the system to add a favorite. |
| 6 | **Undo** three times | The cards come back one by one from the side they left; the trashed photo leaves the trash, the new favorite is unmarked. |
| 7 | × to close, then the same source again | The sources page shows "*N sorted · resume*"; the session resumes at the next card. |
| 8 | A small month or folder, to the end | "All sorted!" with the counts and the space freed; *Open the trash*, *Start over*, *Done* work. |
| 9 | Duplicates → a group with a blurry photo | "Blurry" in red under its resolution; the sharp one marked Best. |

Parts 2 and 3 results on the Galaxy A54, reported by the product owner on 2026-10-27: everything confirmed except part 2 item 3, where some night photos with lights, hazy from mist and cold, are listed as blurry (false positives).

### M4 — similar photos and Stats, to verify on a device

Install the release build over the M3 version (`adb install -r`, do not uninstall), so existing hashes and groups are kept. Before the test, prepare: a photo sent to yourself on WhatsApp and saved (a smaller, recompressed copy), and two photos of the same scene taken a few seconds apart, not as a burst.

| # | Check | Expected |
| --- | --- | --- |
| 1 | Launch and use the app while the first analysis runs (scroll Camera, open photos) | Stays fluid; a bar filling up on the duplicates screen, and "Your library is being analyzed" with "Analyzing: N of M items" on the Stats tab until it ends; similar groups appear every 1,000 photos. Note roughly how long it takes and how many photos the phone has. |
| 2 | Albums → All media | The **Duplicates** tile reads "N items to review · size". |
| 3 | Open it | Chips **All · N**, **Identical copies · N**, **Bursts · N**, **Similar photos · N** (only kinds that have groups); under All, one titled section per kind. Each chip shows only its groups. |
| 4 | The WhatsApp copy | Grouped with the original under Similar photos; the original (higher resolution) marked **Best**, the copy picked. |
| 5 | The two shots taken a few seconds apart | Grouped under Similar photos. |
| 6 | Look through every similar group | Each group's photos really look alike. **Report any group of clearly different photos** (false positive): the most important feedback of this milestone. |
| 7 | **Not duplicates** on a group | It disappears with "These photos won't be grouped again."; still gone after relaunching the app. |
| 8 | Settings → Analysis → Similar photos: **Low**, then **High** | Within seconds, fewer groups with Low, more with High; back to **Medium**. |
| 9 | **Advanced mode** on | No preset selected; three sliders starting from the current values; moving one regroups. Off: back to Medium. |
| 10 | Stats tab | **Space you could free** with a value, *Out of … used by your photos and videos*, a bar, *Photos … · Videos …*; rows Identical copies, Bursts, Similar photos and In the trash with counts and sizes; blurry, screenshots and large videos *Coming soon*. |
| 11 | Tap **Identical copies**, **Bursts**, **Similar photos**, then **In the trash** | The first three open the duplicates screen of the whole library with that chip selected; the last opens the Trash page. |
| 12 | Clean a similar group, then come back to Stats | The reclaimable value drops and **In the trash** grows by the same amount. |
| 13 | Settings → **Analyze the library again** (also M3 item 26) | Spinner while it runs (longer than in M3: thumbnails are read again); afterwards the same groups, and the groups marked Not duplicates stay gone. |
| 14 | Largest font size, duplicates screen | *Not duplicates* and *Move N to trash* fit or stack, never cut off. |

M4 results on the Galaxy A54, reported by the product owner on 2026-10-27 (release build installed over M3):

| Status | Items |
| --- | --- |
| Confirmed | 14 (buttons fit or stack with the largest font) |
| Failed | 3 and 5 to 9: no Similar photos section; the WhatsApp copy and close shots not grouped; the sensitivity and *Analyze the library again* ran a long time without result. 11: Similar photos opened the duplicates screen at the top, not on similar photos |
| Not answered yet | 1 (duration, photo count), 4 (WhatsApp copy) |
| Also reported | Opening a photo shows it blurry for a moment before it turns sharp |

Second test on 2026-10-27, after the fixes below (same day, release build installed over the first):

| Status | Items |
| --- | --- |
| Confirmed | 1 (progress grows, X and Y consistent; leaving the app and coming back resumes where it stopped), 2 and 3 (similar groups show during the scan), 5 (close shots grouped under Similar photos), 6 (no clearly different photos seen in a group), 7 (Not duplicates, still gone after a relaunch), 8 (fewer groups with Low, more with High), 11 (Stats rows open their section), 14 |
| Confirmed later the same day | 3 and 11 with the new chips (clearer), 4 (WhatsApp copy grouped, original Best), 12 (cleaning from Stats) |
| Fixed later the same day | Viewer: photos stayed blurry until zoomed in, and pinching did not zoom; see the third round below |
| Not tested yet | 9, 10, 13 |
| Requested | Identical copies, bursts and similar photos were mixed on the duplicates screen: choice chips added the same day, to check |
| Speed | 20,000 photos. About 760 photos a minute with two thumbnail threads, 860 with four, the app staying fluid: about 25 minutes for the first analysis. Four kept |
| Remarks | The first analysis is long. Similar photos are grouped only on the duplicates screen, not stacked in the timelines: the product owner wants stacking later, see [progress.md](progress.md#m4--engine-level-2) |

Viewer, third round on 2026-10-27. With the product owner's permission, the app logged only durations and image sizes (no names, no ids), read from `logcat` filtered on that tag; the logging was removed afterwards:

| Finding | Detail |
| --- | --- |
| Cause of the blur | MediaStore's thumbnail cache stops at 512 px: asked for 1080 × 1440, it returned 384 × 512 in about 30 ms. The viewer showed that, stretched, until the user zoomed in (5 to 10 s or more, as reported). Neither the queue, the channel nor the analysis delayed it. |
| Fix | Previews decoded from the photo file at the screen's size (`ImageDecoder`): 0.3 to 0.7 s for a 12 MP photo. A first version also decoded wide grid thumbnails (512 × 1109) from the file, 250 to 400 ms each instead of 20 ms; only the viewer does now. Full resolution when zoomed: 0.1 to 0.6 s. |
| Pinch | Pinching did not zoom (double tap did): reproduced in a widget test, a first finger sliding a little before the second landed went to the page view. The zoom now claims the gesture when the second finger lands. |
| Confirmed | "Everything is sharp very quickly": photos sharp at once, also when coming back to a photo already seen. |

Last round on 2026-10-27, reported as "all good" by the product owner: pinch zoom and one-finger pan once zoomed, item 9 (advanced mode), 10 (Stats tab) and 13 (*Analyze the library again*: same groups, the ones marked Not duplicates stay gone). Every item of the M4 checklist is now confirmed.

Fixes for the second test (same checklist): progress "Analyzing: N of M items", groups rebuilt every 1,000 photos, a failing thumbnail batch skipped instead of stopping the scan, native calls that always reply, Stats rows opening their section, two threads rendering thumbnails. The cause of the missing groups is not confirmed: the scan may simply not have reached the end, or a native error may have stopped it.

### M3 — media index, to verify on a device

Install over the M2 version (do not uninstall), so the database migration runs on real data.

| # | Check | Expected |
| --- | --- | --- |
| 1 | First launch after the update | Items trashed in M2 are still in Albums → Trash. The Camera tab shows a skeleton briefly, then fills from the newest photos. |
| 2 | Close the app completely, relaunch | Camera, Videos and Albums show their content at once, without a skeleton. |
| 3 | Take a photo with the camera app, come back to Clean Gallery | The photo appears at the top within a second or two, without pulling down. |
| 4 | Delete a photo in Samsung Gallery, come back | It disappears from the timeline and its album count. |
| 5 | Favorite a photo in Samsung Gallery, come back | The heart shows in Clean Gallery; the photo is in Favorites. |
| 6 | Favorite and trash in Clean Gallery | Instant, as in M2; no list reload or jump. |
| 7 | Scroll far down the Camera tab, then switch apps and come back | The scroll position is kept. |
| 8 | Sort by size, then by name; date filter "Last 30 days" | Same results as in M2. |
| 9 | Albums tab | Folders, counts and covers as in M2. |

Media index status on the Galaxy A54 (Android 16), release build installed over M2, checked by the product owner on 2026-10-26:

| Status | Items |
| --- | --- |
| Confirmed OK | 1 to 9: M2 trash kept by the migration, instant display at launch, camera photos, deletions and favorites made in Samsung Gallery picked up on return, instant actions, scroll position kept, sorts and filters, Albums tab |
| Not tested yet | Limited access (Android 14+ partial selection), first launch on a fresh install of a large library |

### M3 — exact duplicates, to verify on a device

Before the test, make an exact copy: in Samsung Gallery or My Files, copy a photo to another folder; or forward a photo to yourself on WhatsApp and save it twice.

| # | Check | Expected |
| --- | --- | --- |
| 15 | Launch, wait a few seconds, Albums → All media | A **Duplicates** tile above the photos: "N extra copies · size". |
| 16 | Camera tab, if the copy is in another folder | No tile for that pair (the copy is not in Camera). |
| 17 | Open the tile | Groups side by side with resolution, size, date and full path; one photo with **Best**, the others dimmed with a check mark. |
| 18 | Tap a photo | It opens full screen; swiping shows the other copies of the group. |
| 19 | Tap the round button on a picked photo | It is kept (no longer dimmed); the group's button count drops. |
| 20 | **Clean all groups** | Summary "Move N items (size) to the trash?"; after confirming, the groups disappear, *Undo* brings them back. |
| 21 | Albums → Trash, then relaunch the app | The trashed copies are in the trash; launching again does not re-read the files (the tile appears at once). |

Exact duplicates status on the Galaxy A54, checked by the product owner on 2026-10-26: duplicates work. Requested: show each copy's file path to help choose; added the same day and confirmed by the product owner.

### M3 — bursts, to verify on a device

Before the test, take a burst with the Samsung camera: hold the shutter button (or swipe it down, depending on the camera settings) for a second.

| # | Check | Expected |
| --- | --- | --- |
| 22 | Come back to Clean Gallery, Camera tab | A **Duplicates** tile counting the extra shots of the burst. |
| 23 | Open it | A group labelled **Burst** with every shot; the largest file marked **Best**, the others picked. |
| 24 | Two photos taken separately a few seconds apart | Not in a Burst group (from M4 they may appear under Similar photos). |
| 25 | **Move N to trash** on the burst | Only the best shot remains in the Camera tab; *Undo* brings the others back. |

Bursts status on the Galaxy A54, checked by the product owner on 2026-10-26: burst detection works.

| # | Check | Expected |
| --- | --- | --- |
| 26 | Settings → Analysis → **Analyze the library again** | Snackbar "Analysis started"; a spinner on the row while it runs; afterwards, timelines, dates, duplicates and bursts are as before. |

### M3 — capture dates, to verify on a device

| # | Check | Expected |
| --- | --- | --- |
| 10 | First launch after the update | Lists show at once; within a few seconds, received photos (WhatsApp, Signal…) move to the day in their file name. |
| 11 | Albums → WhatsApp Images (or another messaging folder), photos received long after they were taken | Grouped by the date in their name (`IMG-20240315-WA…` → March 15, 2024), not the day they arrived. |
| 12 | Camera tab | Unchanged: camera photos keep their date and time. |
| 13 | Settings → Display → **Corrected dates** off, then back to the timelines | Received photos go back to the day they arrived; on again: back to their real date. Restart: the choice is kept. |
| 14 | Date filter "Last 30 days" with corrected dates on | Old photos received recently are not in it. |

Capture dates status on the Galaxy A54 (Android 16), release build installed over the media index version, checked by the product owner on 2026-10-26:

| Status | Items |
| --- | --- |
| Confirmed OK | 10 to 14: dates resolved after the update without slowing the display, WhatsApp photos grouped by the date in their name, camera photos unchanged, Corrected dates switch (kept after a restart), date filter on corrected dates |

### M2 — to verify on a device

| # | Check | Expected |
| --- | --- | --- |
| 1 | Viewer: favorite a photo | System confirmation (none with Media management); heart filled; same favorite in Samsung Gallery. |
| 2 | Selection: long press, drag across rows | The whole range is selected; the grid scrolls near the edges. |
| 3 | Selection: favorite several items | One system confirmation for all. |
| 4 | Move to trash from the viewer and from a selection, then Undo | Items disappear, then come back. |
| 5 | Albums → Trash | Items with "30 days"; restore works. |
| 6 | Delete for good from the Trash | Our confirmation, then one system confirmation; items gone from Samsung Gallery too. |
| 7 | With Media management granted, repeat 1 and 6 | **No system confirmation** (checks the bypass for favorites in particular). |
| 8 | Set retention to 1 day, trash an item, come back the next day | "1 item has expired" offered once. |
| 9 | Share a JPEG with "Remove location" on, to an app that shows location (e.g. send to yourself and open in Google Photos) | No location on the received photo; the original still has it. |
| 10 | Share a HEIC photo with location removed | Received as JPEG, without location. |
| 11 | Share with "Remove location" off | Original sent, with location. |
| 12 | Share a video with location removal on | Warning in the sheet; video sent as is. |
| 13 | Settings: theme, language, default columns | Applied at once and after restarting the app. |
| 14 | Sort a tab, restart the app | The sort is restored. |
| 15 | Settings → Permissions: change one in the system settings, come back | Status refreshed. |
| 16 | Videos tab, including videos received from messaging apps | Every video has a thumbnail (MediaStore's, the embedded cover, or the frame at 10 %). |
| 17 | Camera tab | Only photos taken with the camera; no screenshots or WhatsApp images; those are in Albums → All media. |

M2 status on the Galaxy A54 (Android 16), checked by the product owner on 2026-10-25:

| Status | Items |
| --- | --- |
| Confirmed OK | 1 favorites (after the optimistic update fix), 2 drag selection, 4 trash and undo, 6 delete for good (one Android confirmation), 9 and 11 sharing, 13 theme, language and columns, 16 video thumbnails, 17 Camera tab; overall fluidity on a release build |
| Not tested yet | 3 favorite batch prompt, 5 restore, 7 behaviour with Media management, 8 expiry offer the next day, 10 HEIC sharing, 12 video sharing warning, 14 sort restored after restart, 15 permission refresh |

### M1 — to verify on a device

| # | Check | Expected |
| --- | --- | --- |
| 1 | Photos tab with a real library | Newest first; "Today", "Yesterday", then dates; photos only. |
| 2 | Videos tab | Videos only, with duration badges. |
| 3 | Scroll quickly through thousands of items | Smooth, thumbnails fill in fast, no freeze; the end of the library appears as chunks load. |
| 4 | Pinch out / in on a grid | 2 to 6 columns, one step per gesture; month headers from 5 columns. |
| 5 | Albums tab | All media and Favorites counts match the system gallery; folders sorted by size. |
| 6 | Favorites | Same items as the favorites in Google Photos / Samsung Gallery. |
| 7 | Tap a photo | Flies to full screen; swipe between items; back returns to the same place. |
| 8 | Pinch and double-tap in the viewer | Zooms; double-tap again fits; no page swipe while zoomed. |
| 9 | Tap in the viewer | Bars and system UI hide and show. |
| 10 | Open a video | Plays; pause, seek, mute, rotate work; swiping away pauses it. |
| 11 | HEIC photo, panorama, very large photo | Displays; no crash or out-of-memory. |
| 12 | Take a new photo, pull down on Photos | The new photo appears. |
| 13 | Android 14+ partial access | Only the shared photos, with the "Allow all" banner. |
| 14 | **Sort by date, name, size, duration**, both directions | Correct order; no crash (checks that MediaStore accepts the `CASE` and `LOWER` SQL). |
| 15 | Date presets and a custom range | Only items of the period; counts plausible; headers match the period. |
| 16 | Filter on a folder | Only that folder's items in the period. |
| 17 | Open the viewer after sorting | Swipes in the sorted order. |
| 18 | Fast-scroll thumb | Appears when scrolling; dragging jumps; bubble shows the month (date sort) or the size (size sort). |
| 19 | Scroll far, then stop | Thumbnails appear quickly (compare with the first test). |
| 20 | Viewer: swipe left and right | Next and previous photo or video. |
| 21 | Viewer: open, zoom | The photo shows sharp quickly; zooming loads full detail without a pause. |
| 22 | Video controls | Play/pause, seek, mute and rotate respond on the first tap. |

Device tests on the Galaxy A54 (2026-10-25):

1. Items 1–2, 4–7, 14–17 OK; Favorites match the system gallery. Broken: viewer swipe, video controls; slow: viewer display, grid after a far scroll.
2. After fixes: fast-scroll thumb (18) and viewer swipe (20) OK. Still broken: video progress bar in the middle of the screen; still slow: grid and viewer display.
3. Fixed since: progress bar height (22), native thumbnail and preview loader (19, 21).
4. Photos and Videos became very fast; the Albums tab was still slow. Fixed since: one native query for all folders and cached folder paths.
5. Albums tab fast as well.

M1 status on the Galaxy A54 after these rounds:

| Status | Items |
| --- | --- |
| Confirmed OK | 1 Photos timeline, 2 Videos tab, 3 and 19 scrolling speed, 4 pinch, 5 Albums (now fast), 6 Favorites match the system gallery, 7 and 20 viewer swipe, 14 sorting, 15 date filters, 17 viewer order after sorting, 18 fast-scroll thumb, 21 viewer display speed |
| Fixed, not re-confirmed | 22 video progress bar position and seeking (layout test added) |
| Not tested yet | 8 zoom gestures in detail, 9 immersive mode, 10 rotate, 11 HEIC / panorama / very large photo, 12 pull-to-refresh after a new photo, 13 partial access, 16 filter on a folder |

These checks were done by the product owner on their own phone; the app was installed over adb and nothing on the phone was inspected remotely.

### Already checked on a Samsung Galaxy A54, Android 16 (2026-10-25)

With the first design (before [ADR 0008](decisions/0008-navigation-and-visual-identity.md)):

- The debug APK installs and starts; Impeller runs on Vulkan; no crash.
- The French translation is displayed (onboarding and tabs).
- The onboarding flag persists: after onboarding, relaunching opens the tabs.

Not checked yet on this phone: the permission prompts (items 4 to 9) and the new design. The phone turns its screen off after 30 seconds, faster than the remote test loop; keep the screen on while testing.

### Already checked on the Android 14 emulator (2026-10-25)

- The debug APK installs and starts without a crash or Flutter exception in `logcat`.
- The database opens and `runApp` completes: the widget tree, read through the Dart VM service (`ext.flutter.debugDumpApp`), contains `OnboardingScreen` under the router.

The screen itself could not be seen; see the next section.

### Emulator on the development machine

The Android emulator is installed (`~/sdk/android/emulator`, AVD `cg_api34`: Pixel 6, Android 14, 3 GB), but is not usable for UI checks on this machine:

- It runs as user `claude`, which cannot open the desktop display (`:0` belongs to the desktop user), so it runs without a window and without GPU, with software rendering (SwiftShader).
- On this CPU (i5-7200U, 2 cores), software rendering makes Android's own System UI and launcher stop responding, even with 3 GB of RAM.
- `/dev/kvm` access for `claude` is a temporary ACL (`sudo setfacl -m u:claude:rw /dev/kvm`); logind removes it from time to time and at reboot.

Ways forward: test on a USB phone (preferred), or let the emulator use the GPU by granting display access from the desktop session (`xhost +SI:localuser:claude`, plus `sudo apt install libxcb-cursor0`), or try a lighter ATD system image.

## Continuous integration

[.github/workflows/ci.yml](../.github/workflows/ci.yml) runs formatting, analysis, tests, APK and AAB builds on every push and pull request, plus a Markdown lint and an offline link check on all documentation. The build job first removes preinstalled toolchains it does not use (.NET, Haskell, Swift, CodeQL…): on 2026-10-27 the runner ran out of disk space building the release app bundle after the debug APK.
