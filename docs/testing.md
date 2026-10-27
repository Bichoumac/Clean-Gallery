# Testing

How Clean Gallery is tested: test layers, commands, fakes and fixtures. Every milestone adds tests for what it builds; a milestone is not done until the suite passes.

Last updated: 2026-10-27 — Milestone M4

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
| [app_database_test.dart](../test/core/database/app_database_test.dart) | Schema version, migration 1 → 2 with a trashed item, enum storage, foreign keys, cascade delete, settings repository. |
| [onboarding_controller_test.dart](../test/features/onboarding/onboarding_controller_test.dart) | Permission flow for granted, limited and denied access; persistence of completion. |
| [onboarding_screen_test.dart](../test/features/onboarding/onboarding_screen_test.dart) | Privacy promise shown, full flow, skip, returning users skip onboarding. |
| [dependency_rules_test.dart](../test/architecture/dependency_rules_test.dart) | Pure-Dart engine and domain, no direct Android imports in features, no `MANAGE_EXTERNAL_STORAGE`. |
| [navigation_test.dart](../test/core/router/navigation_test.dart) | Five icon-only tabs, switching tabs, Stats content, 48 dp touch targets. |
| [timeline_test.dart](../test/domain/timeline_test.dart) | Day and month sections, grid rows, grouping by column count. |
| [media_providers_test.dart](../test/core/media/media_providers_test.dart) | First chunk then the rest from the index, reload in place without a loading state, column limits, duration format. |
| [best_picker_test.dart](../test/analysis/best_picker_test.dart) | Each best-pick rule in order, best item first. |
| [burst_test.dart](../test/analysis/burst_test.dart) | Burst names of Samsung and Google cameras, different bursts and folders, ordinary names. |
| [duplicates_test.dart](../test/core/media/duplicates_test.dart) | Only size collisions hashed, exact groups, no re-read, filter by folder, trash and undo, changed file, favorite kept, burst groups, a burst saved twice. |
| [duplicates_flow_test.dart](../test/features/duplicates/duplicates_flow_test.dart) | Duplicates tile and count, screen, clean all with summary, keep every copy, open a photo full screen. |
| [perceptual_hash_test.dart](../test/analysis/perceptual_hash_test.dart) | Hamming distance, area resize; the same photo recompressed, resized, brightened, cropped stays close; 40 unrelated scenes stay apart (false positive regression). |
| [similarity_test.dart](../test/analysis/similarity_test.dart) | Multi-index search against brute force, union-find, strict and loose rules, aspect ratio, chains, ignored pairs, certain groups, presets, confidence, a mixed photo set. |
| [similar_photos_test.dart](../test/core/media/similar_photos_test.dart) | Similar scan through the media source: groups, photos only, hashes kept, Not duplicates, changed file, new thresholds without re-reading, exact copies stay certain, folder filter. |
| [similar_flow_test.dart](../test/features/duplicates/similar_flow_test.dart) | Similar photos section, Not duplicates, Stats values and link to the duplicates screen. |
| [storage_summary_test.dart](../test/features/stats/storage_summary_test.dart) | Dashboard values by category, an item counted once, the trash, an empty library. |
| [capture_date_test.dart](../test/analysis/capture_date_test.dart) | File name date patterns, rejected names, date-only names, resolution order. |
| [android_media_source_test.dart](../test/platform/android_media_source_test.dart) | When MediaStore's `DATE_TAKEN` counts as a metadata date. |
| [media_index_test.dart](../test/core/media/media_index_test.dart) | Capture dates resolved during a sync, rules version, sort by corrected or platform date; sync plan; first, unchanged and incremental syncs; analysis kept unless the file changed; platform version change; denied and limited access; merged calls; index filters, sorts, date range, folders and trash exclusion. |
| [library_test.dart](../test/features/library/library_test.dart) | Timeline headers, photo/video filters, empty, denied and limited states, Albums and folder pages, opening the viewer, pinch gesture, pull-to-refresh indexing new items. |
| [sort_filter_test.dart](../test/features/library/sort_filter_test.dart) | Date ranges and presets, plain rows, sort by name, date preset and chip removal, empty period, viewer order, per-tab state. |
| [fast_scroller_test.dart](../test/features/library/fast_scroller_test.dart) | Thumb visibility, drag jump with month bubble, size bubble, short lists, size formatting. |
| [viewer_test.dart](../test/features/viewer/viewer_test.dart) | Swipe both ways, pinch then pan without page change, double-tap back, top bar height. |
| [video_controls_test.dart](../test/features/viewer/video_controls_test.dart) | Video progress bar at the bottom, play button centered, portrait and landscape. |
| [trash_repository_test.dart](../test/core/database/trash_repository_test.dart) | Trash order and expiry, live ids, restore, forget, duplicates, days left. |
| [app_settings_test.dart](../test/core/settings/app_settings_test.dart) | Default, stored and invalid settings, similarity settings; sort encoding; view keys. |
| [trash_flow_test.dart](../test/features/trash/trash_flow_test.dart) | Trash from the viewer with undo, Trash page, restore, delete for good, declined prompt, expiry offer, silent purge, Trash album count. |
| [selection_test.dart](../test/features/library/selection_test.dart) | Long press, tap, drag range, trash with undo, favorite, share, back. |
| [settings_screen_test.dart](../test/features/settings/settings_screen_test.dart) | Theme, language, default columns, corrected dates switch, sensitivity and advanced mode, permission statuses, sort saved and restored. |

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

Release builds are signed with the debug key for now (M9), so they install over a debug build and keep the app data.

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
| 2 | Brand palette and Manrope | any | Ink/paper surfaces, lime accent, Manrope typeface at the right weights ([design.md](design.md)). |
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

[.github/workflows/ci.yml](../.github/workflows/ci.yml) runs formatting, analysis, tests, APK and AAB builds on every push and pull request, plus a Markdown lint and an offline link check on all documentation.
