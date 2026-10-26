# Testing

How Clean Gallery is tested: test layers, commands, fakes and fixtures. Every milestone adds tests for what it builds; a milestone is not done until the suite passes.

Last updated: 2026-10-25 — Milestone M2

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

## Current coverage (M0)

| File | What it checks |
| --- | --- |
| [app_database_test.dart](../test/core/database/app_database_test.dart) | Schema version, enum storage, foreign keys, cascade delete, settings repository. |
| [onboarding_controller_test.dart](../test/features/onboarding/onboarding_controller_test.dart) | Permission flow for granted, limited and denied access; persistence of completion. |
| [onboarding_screen_test.dart](../test/features/onboarding/onboarding_screen_test.dart) | Privacy promise shown, full flow, skip, returning users skip onboarding. |
| [dependency_rules_test.dart](../test/architecture/dependency_rules_test.dart) | Pure-Dart engine and domain, no direct Android imports in features, no `MANAGE_EXTERNAL_STORAGE`. |
| [navigation_test.dart](../test/core/router/navigation_test.dart) | Five icon-only tabs, switching tabs, Stats content, 48 dp touch targets. |
| [timeline_test.dart](../test/domain/timeline_test.dart) | Day and month sections, grid rows, grouping by column count. |
| [media_providers_test.dart](../test/core/media/media_providers_test.dart) | Chunked loading (first chunk, then the rest), column limits, duration format. |
| [library_test.dart](../test/features/library/library_test.dart) | Timeline headers, photo/video filters, empty, denied and limited states, Albums and folder pages, opening the viewer, pinch gesture. |
| [sort_filter_test.dart](../test/features/library/sort_filter_test.dart) | Date ranges and presets, plain rows, sort by name, date preset and chip removal, empty period, viewer order, per-tab state. |
| [fast_scroller_test.dart](../test/features/library/fast_scroller_test.dart) | Thumb visibility, drag jump with month bubble, size bubble, short lists, size formatting. |
| [viewer_test.dart](../test/features/viewer/viewer_test.dart) | Swipe both ways, pinch then pan without page change, double-tap back, top bar height. |
| [video_controls_test.dart](../test/features/viewer/video_controls_test.dart) | Video progress bar at the bottom, play button centered, portrait and landscape. |
| [trash_repository_test.dart](../test/core/database/trash_repository_test.dart) | Trash order and expiry, live ids, restore, forget, duplicates, days left. |
| [app_settings_test.dart](../test/core/settings/app_settings_test.dart) | Default, stored and invalid settings; sort encoding; view keys. |
| [trash_flow_test.dart](../test/features/trash/trash_flow_test.dart) | Trash from the viewer with undo, Trash page, restore, delete for good, declined prompt, expiry offer, silent purge, Trash album count. |
| [selection_test.dart](../test/features/library/selection_test.dart) | Long press, tap, drag range, trash with undo, favorite, share, back. |
| [settings_screen_test.dart](../test/features/settings/settings_screen_test.dart) | Theme, language, default columns, permission statuses, sort saved and restored. |

App-level widget tests use `pumpTestApp` ([pump_app.dart](../test/helpers/pump_app.dart)): the whole app on a phone-sized screen (1080 × 2400 px at 3×) with all fakes, so tests see what a user would. They are declared with `testApp` instead of `testWidgets`: it unmounts the app at the end, even after a failure, and lets Drift close its stream queries (Drift closes them on a zero-length timer; without this step Flutter reports a pending timer and the run hangs).

Run the suite with a per-test timeout so a hang fails fast: `flutter test --timeout 60s`.

## Fixtures

From M3, the analysis engine is tested against a small photo set in `test/fixtures/`: exact duplicates, recompressed and resized copies, bursts, and close-but-different photos for false-positive regression tests. Fixtures are small (a few kilobytes each) and generated or freely licensed.

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
