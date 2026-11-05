# Project: Clean Gallery — Android gallery app built with Flutter

## Context and goal
You will build **Clean Gallery**, a photo and video gallery app for Android, written in **Flutter**.
It works like a classic gallery (browse folders, view photos, play videos) and adds **cleanup** tools: a virtual folder that groups potential duplicates, a swipe-to-sort mode, and a trash with a configurable retention period.

The app is **free with very light, unobtrusive ads**, and offers a single **"Remove ads" in-app purchase (€4.99)**. All features are available to everyone; the purchase only removes ads.

The app targets **Android only** for now, but the architecture must allow adding iOS later **without touching the UI or the analysis engine**: all platform-specific code (media access, native features, ads, billing) must be isolated behind interfaces.

The project must be **thoroughly documented in Markdown throughout development**, so that both a human and an AI assistant can understand, maintain and extend it without reading the whole codebase.

## Technical constraints
- Flutter (latest stable), Dart with null safety, strict lints (`flutter_lints` or `very_good_analysis`).
- Android **minSdk 30 (Android 11)**, targetSdk = latest version required by the Play Store.
- **Never use `MANAGE_EXTERNAL_STORAGE`.**
- Before adding a package, check that it is actively maintained and compatible with the Flutter version in use. If a package suggested below is not suitable, propose an alternative and explain why.
- Code (identifiers, comments) and documentation are in English. The UI is localized in **English and French** (ARB / `flutter_localizations`), following the system language.
- No secrets or production IDs hardcoded in the source: AdMob app ID and ad unit IDs come from build configuration (flavors / `--dart-define` / Gradle properties).

## Recommended stack
- Media access: `photo_manager`
- Local database: `drift` (SQLite), running in a background isolate
- State management: `flutter_riverpod` (+ `riverpod_generator` where relevant)
- Navigation: `go_router`
- Immutable entities: `freezed`
- Viewer and zoom: `photo_view`
- Video: `media_kit` (or `video_player` + `chewie`)
- Sharing: `share_plus`
- Map: `flutter_map` + OpenStreetMap tiles + marker clustering
- Image processing and filters: `image` and/or color matrices
- Face detection and face embeddings (People, added 2026-11-01): small on-device models with licenses that allow a commercial app, run natively; candidate pair YuNet (detection) + SFace (embeddings) from the OpenCV model zoo. The choice gets an ADR before any code (see [People](#people-face-recognition-added-2026-11-01)).
- Background work: none (purge at launch, [ADR 0013](docs/decisions/0013-trash-purge-without-background-job.md)); scheduled notifications for memories and rituals only
- Ads: `google_mobile_ads` (AdMob) + Google **UMP SDK** for consent (bundled with `google_mobile_ads`)
- In-app purchase: `in_app_purchase` (official plugin)
- Native code: a **Kotlin** module via MethodChannel for anything packages don't cover (system favorites, "Media management" special permission, stripping GPS from EXIF, MediaStore requests)

## Architecture
Layered architecture, organized **by feature**:

- **Presentation**: Material 3 widgets, Riverpod providers, go_router routes
- **Domain**: entities (`MediaItem`, `Album`, `DuplicateGroup`, `TrashEntry`…), use cases, repository interfaces
- **Data**: repository implementations and data sources:
  - `MediaSource` (interface) → `AndroidMediaSource` (photo_manager + native module)
  - `PlatformBridge` (interface) → `AndroidPlatformBridge` (Kotlin MethodChannel)
  - `AdsService` (interface) → `AdMobAdsService`
  - `PurchaseService` (interface) → `PlayPurchaseService`
  - `LocalDatabase` (Drift)
- **Analysis engine**: pure Dart package, **independent from Flutter and the UI**, running in an isolate, fully unit-testable

All services behind interfaces must be mockable in tests and replaceable by an iOS implementation later.

Expected `lib/` structure:

    lib/
      core/          theme, Drift database, router, permissions, utils, l10n, build config
      analysis/      detection engine (pure Dart)
      platform/      interfaces + Android implementations (media, native bridge, ads, billing)
      features/
        onboarding/
        library/       folders, grid, timeline view
        viewer/        photo viewer, video player, info panel
        favorites/
        duplicates/    virtual folder, groups, comparison
        swipe/         swipe-to-sort
        trash/         trash
        cleanup/       Clean tab
        editor/        editing and filters
        map/
        search/
        settings/
        monetization/  ads, consent, "Remove ads" purchase

## Database schema (Drift)
- `assets`: MediaStore id, album/folder, relative path, file name, mime type, kind (photo/video), size, width, height, duration (video), modified date, **capture date + date source** (exif / filename / file), content hash (xxHash), dHash, pHash, blur score, burst ID, is_screenshot, latitude, longitude, camera model, `analysis_version`
- `duplicate_groups`: id, kind (`exact`, `burst`, `similar`), computed_at
- `duplicate_members`: group_id, asset_id, `is_suggested_keep`, score
- `ignored_pairs`: asset_a, asset_b (pairs marked "not duplicates" by the user)
- `trash`: asset_id, `trashed_at`, `expires_at`, original folder
- `swipe_history`: session, order, asset_id, action (`keep` / `trash` / `favorite`)
- `settings`: key/value (including the cached ad-free status and whether the one-time upgrade prompt has been shown)
- Added 2026-11-01, final columns decided in each milestone:
  - `user_albums`: id, name, cover asset id (optional), created_at, sort order
  - `user_album_items`: album_id, asset_id, added_at (an item can be in several albums)
  - `faces`: id, asset_id, bounding box, landmarks, embedding (blob), quality, person_id, `assigned_by` (`auto` / `user`), `analysis_version`
  - `persons`: id, name (optional), cover face id, hidden, created_at
  - `face_rejections`: face_id, person_id ("Not this person": never assigned again)
  - `memories`: id, kind (`week_years_ago`, `on_this_day`, `trip`…), period start and end, created_at, seen_at, dismissed
  - `slideshows`: id, title, options (duration, transition, order, videos, music), created_at; `slideshow_items`: slideshow_id, position, asset_id
  - `rituals`: id, source (memories, saved slideshow, album, person, period), recurrence (weekday or day of month, time), enabled

Set up migrations from day one. `analysis_version` allows re-running analyses when an algorithm changes.

## Permissions and onboarding
A simple, illustrated onboarding screen on first launch that:
- States clearly: **"Your photos never leave your device."**
- Requests `READ_MEDIA_IMAGES` + `READ_MEDIA_VIDEO` (Android 13+), `READ_EXTERNAL_STORAGE` (Android 11–12). Handle Android 14+ **partial access** (`READ_MEDIA_VISUAL_USER_SELECTED`) with a clear message and a button to grant broader access.
- Requests `ACCESS_MEDIA_LOCATION`, required to read GPS data from EXIF (map, metadata).
- **Optional but recommended**: requests the **"Media management"** special permission (`MANAGE_MEDIA`, Android 12+), explaining that it avoids a confirmation prompt on every delete or favorite. Provide a button that opens the system setting directly. The app must remain fully functional without it, falling back to MediaStore confirmation requests.

The ad consent form (UMP) is shown after onboarding, not before the permission screens.

Permission status is visible and changeable in Settings.

## Features

### Navigation (bottom tabs: Photos · Folders · Clean)
- **Photos**: all photos and videos, in a **timeline view** with day or month headers.
- **Folders**: grid of folders with thumbnail and item count. At the top: "All photos", then "Favorites" (virtual album), then the actual folders.
- **Grid**: cached thumbnails, smooth scrolling with 10,000+ items, **pinch-to-zoom** to change the column count (2 to 6), duration badge on videos, heart on favorites.
- **Multi-select** with long press then **drag-to-select** across the grid. Action bar: share, favorite, trash.
- Trashed items are hidden everywhere in the app.

### "Duplicates" virtual folder
- In every folder grid (including "All photos"), a **special tile at the top**: distinct icon + badge with the number of affected items. It exists only in the UI; **nothing is created on disk**.
- It groups duplicates **among the media of the currently displayed folder**. Groups are computed once for the whole library, then **filtered** by the displayed folder (only members present in the folder are kept, and a group is shown only if at least 2 members remain). "All photos" therefore also detects duplicates across folders.
- When opened: list of groups in two sections: **"Certain duplicates"** (exact + bursts) and **"Similar photos"**.
- Each group shows photos side by side with resolution, size, date and sharpness. The suggested photo to keep has a "Best" badge; the others are **pre-selected**.
- Actions: confirm all (move selected items to trash), adjust the selection, open a photo full screen, "Not duplicates" (adds to `ignored_pairs`).
- Global button: "Clean all groups", with a summary ("128 items, 1.4 GB") before confirmation.

### Analysis engine
Runs in an isolate, **incremental** (only new or modified media are analyzed), resumable after interruption, with discreet progress in the UI (thin bar or indicator in the Clean tab). Analyses run on **thumbnails** whenever possible; never bulk-load full-size originals.

1. **Date resolution**, in this order: EXIF `DateTimeOriginal` (+ `OffsetTimeOriginal`), then file name via regex (`IMG_YYYYMMDD_HHMMSS`, `PXL_YYYYMMDD_HHMMSSmmm`, `VID_…`, `Screenshot_YYYYMMDD-HHMMSS`, `Screenshot_YYYY-MM-DD-HH-MM-SS`, `signal-…`, `WhatsApp Image YYYY-MM-DD at HH.MM.SS`, `IMG-YYYYMMDD-WA####`, Samsung formats, etc.), then the MediaStore file date. Store the source.
2. **Exact duplicates**: same size, then same xxHash of the content.
3. **Bursts**: same burst identifier (metadata, or file name patterns such as `_BURST`, `_COVER`).
4. **Similar photos**: 64-bit dHash and pHash, Hamming distance. Search through a **BK-tree** (no O(n²) comparison). A pair is similar if:
   - pHash distance ≤ strict threshold (default 6) **and** aspect ratio within ±2%; or
   - time difference ≤ time window (default 10 s) **and** pHash distance ≤ loose threshold (default 12).
   Same camera model and nearby GPS increase the confidence score. Pairs in `ignored_pairs` are excluded. Groups are built with **union-find**.
5. **Videos**: exact duplicates (size + hash); near-duplicates if same duration (±0.5 s), same resolution and close dates.
6. **Sharpness**: variance of the Laplacian on the grayscale thumbnail.
7. **Screenshots**: Screenshots folder, file name pattern, or dimensions matching the device screen.
8. **BestPicker** for each group: favorite > highest resolution > sharpest > largest file size > oldest.

Thresholds are exposed in Settings as sensitivity presets (Low / Medium / High) with an advanced mode.

### Viewer
- Full screen, horizontal swipe between media, pinch-to-zoom and double-tap to zoom, "hero" transition from the grid, tap to hide or show the UI.
- Action bar: **Share**, **Favorite**, **Edit**, **Info**, **Delete** (to trash, with an "Undo" snackbar).
- Built-in **video playback**: play/pause, progress bar, sound, full screen, rotation.
- **Info panel**: a bottom sheet that slides up **with a translucent blurred background** over the photo. It shows the date (and its source), file name, path, size, resolution, camera, lens, ISO, aperture, shutter speed, focal length, and GPS location with a mini map.

### Favorites (synced with the system)
- Read and write the MediaStore `IS_FAVORITE` field, so favorites are shared with other gallery apps (Google Photos…).
- Write directly if "Media management" is granted; otherwise use `MediaStore.createFavoriteRequest` (batch requests when multiple items are selected).

### Trash (managed by the app)
- Moving to trash = a record in the `trash` table. The file stays on disk but disappears from the app.
- Retention period configurable in Settings (1 to 90 days, **30 by default**).
- Trash screen: grid showing remaining days per item, restore, permanently delete, empty trash.
- **Purge on expiry**: at app launch and through a daily WorkManager task. With "Media management", delete directly. Without it, at launch: "X items have expired, permanently delete them?" followed by **a single** system `createDeleteRequest` for the whole batch.
- Every delete in the app (viewer, duplicates, swipe, cleanup, selection) goes through the trash.

### Sharing
- Share one or more media items through the system share sheet.
- Option (default setting + toggle at share time): **remove GPS location**. A temporary copy without GPS tags is shared (via `ExifInterface` on the Kotlin side); the original stays untouched.

### Editing and filters
- Crop (free, 1:1, 4:3, 16:9…), rotate, flip.
- Adjustments: brightness, contrast, saturation, exposure, warmth.
- About ten **classic filters** with thumbnail previews: Black & White, Sepia, Vintage, Warm, Cool, Vivid, Fade, Dramatic, Noir, Soft.
- Saving: **"Save as copy" by default**. "Replace original" option, in which case the original goes to the app trash.
- Preserve EXIF metadata (updating orientation and dimensions).

### "Clean" tab
- **Storage dashboard**: total space used by media and reclaimable space per category.
- Tappable cards:
  - **Duplicates** (whole library) → duplicates screen
  - **Sort mode (swipe)**
  - **Blurry or failed photos** (low sharpness score, very dark photos)
  - **Screenshots** older than N days (N configurable, 30 by default)
  - **Large videos** (> 100 MB, sorted by size)
- Each list supports selection and batch move to trash.

### Swipe mode
- Full-screen cards, one at a time, from a chosen source (a folder, "All photos", a month, blurry photos…).
- **Left = trash, right = keep.** Equivalent buttons at the bottom for users who don't swipe, plus a favorite button.
- An **"Undo" button that is always visible**, undoing the last action with an animation bringing the card back, multiple levels deep.
- Sessions are resumable (saved in `swipe_history`), with progress ("42 / 300") and a summary at the end of the session.

### Map
- OpenStreetMap map with geotagged photos, markers grouped into clusters with a thumbnail.
- Tapping a cluster → grid of photos in that area.
- Respect the OpenStreetMap tile usage policy (proper user agent, attribution displayed).

### Search
- Combinable filters: date range, type (photo / video / screenshot), folder, favorites, file name, geographic area (picked on the map).

### User albums (added 2026-11-01)
- **App albums only** (product owner, 2026-11-01): an album is a list stored in the app's database. The app **never moves, copies or deletes a file** for an album: deleting an album or uninstalling the app leaves every photo on the device. A photo can be in several albums; the Camera timeline keeps its photos; no system confirmation is needed. Other gallery apps do not see these albums.
- **Create an album** from the Albums tab (*New album*) or from the selection bar of any grid (*Add to album* → pick an existing album or *New album*).
- **Add to an existing album** the same way, from a multi-selection or from the viewer's actions.
- An album page works like a folder page (timeline, sort, search, selection, viewer, slideshow) and also offers: *Remove from album* (the photo stays on the device), *Rename*, *Choose cover*, *Delete album* (the photos stay on the device; the confirmation says so).
- Albums tab: a **My albums** section between the virtual albums and the device folders.
- Trashed items disappear from albums; restored items come back in them. An item deleted for good leaves its albums.

### People (face recognition) (added 2026-11-01)
- **On the phone only, never on a server** (product owner, 2026-11-01): the models are **bundled in the app** and run locally; they are never downloaded at run time. No cloud API, no Google Play services or ML Kit (which may download models and send usage data), no network call from the face code. No image, face or measurement ever leaves the phone. A test checks that the face code and its native side use no network API.
- This is the only machine-learning feature of the app (see [Out of scope](#out-of-scope-do-not-build)).
- **Opt-in**, off by default: a card in the Albums tab and a switch in Settings explain what it does before the first scan. *Delete face data* in Settings erases every face, person and name.
- **Scan**: **photos only** (no videos). Incremental, while the app is open, like the similar photos analysis (pauses in the viewer, progress shown, resumes later). Faces too small or blurry are ignored.
- **Grouping**: face embeddings compared by cosine distance and grouped into persons; a person appears once it has at least N photos (N tuned on the product owner's photos, around 3). A sensitivity setting like the similar photos one.
- **People** in the Albums tab: a row of round face thumbnails, *See all*, then a grid of all persons; a person opens a timeline of their photos (sort, search, selection, slideshow).
- **Naming** a person (optional); named persons first.
- **Merge** two persons (one person recognized as two): from a person's page *Merge with…* → pick the other person, or select several persons in the grid → *Merge*. Their faces move to one person; the name is chosen when both have one. Merges are kept when the grouping runs again (faces assigned by the user are never moved by the automatic grouping).
- **Corrections**: on a person's page, select photos → *Not this person* (stored in `face_rejections`); *Hide this person* (removed from People, kept in the database).
- **Viewer info panel**: the persons found in the photo, each opening their page.
- **Search**: a *Person* chip among the criteria.
- **Privacy and legal**: face measurements are biometric data under the GDPR, even when they stay on the device. Opt-in, a clear explanation, deletion at any time and no transfer keep the app on the safe side; the release checklist (`docs/release.md`, M12) must cover the Play Console *Data safety* answers for it.
- **Model**: detection and embedding models must have licenses that allow use in an app with ads; many published face recognition weights are for research only. The choice, its license, its size (a few MB) and its speed on the Galaxy A54 are recorded in an ADR before any code.

### Slideshows and memories (added 2026-11-01)
- **Manual slideshow**: a *Slideshow* button on every album page (folders, user albums, Favorites, persons, search results), on a multi-selection, and from a **date range** (Albums → *Slideshow* → pick a period, with the period choices of the sort sheet).
- **Playback**: full screen, dark, screen kept on; photos one after another with a transition (crossfade, slow zoom "Ken Burns"); tap to show controls (pause, previous, next, close). **Videos** play **muted, 10 s at most**, then the next item. Duplicates (except the best one) and blurry photos are skipped by default.
- **Options** (sheet before starting, remembered): duration per photo (3 / 5 / 8 s), transition, order (by date / shuffled), include videos, **music**:
  - *None*;
  - **free tracks bundled with the app**: a few tracks whose license allows redistribution in an app with ads (CC0 preferred), credited in About; each adds a few MB to the app;
  - **a track from the phone**, picked with the system file picker (no audio permission needed; the app keeps read access to that one file only).
  - The music loops and fades out at the end; it stops when the slideshow is paused.
- **Saved slideshows** (product owner, 2026-11-01): a *Save* button, on the user's tap only, stores the slideshow (title, its photos and videos in order, its options and music) in the database. **My slideshows** (Albums tab) lists them; each plays again at any time, can be renamed or deleted. Saved, not exported: no video file is written. Photos trashed or deleted since are skipped.
- **Automatic memories**: built by the app from the capture dates, **only while it is open** (no background work):
  - **This week, N years ago**: photos taken in the same week 1, 2, 3… years ago ("1 year ago").
  - **On this day** when that day has enough photos.
  - Later, possibly: trips (from the locations already read for the map), a person over the years.
  - A memory needs a minimum number of good photos (not blurry, one per duplicate group), else it is skipped.
  - Shown as a **memory card at the top of the Camera tab**; tap → slideshow (with *Save*), ✕ → dismissed. Past memories stay in a **Memories** list (Albums tab) until dismissed.
- **Weekly notification and rituals**, with **no background task** (product owner, 2026-11-01):
  - Memories default to **once a week**; Settings: Off / Every week / Every month, day and time.
  - **Rituals**: the user schedules a recurring slideshow, for instance "every Sunday at 7 pm: memories of the week", "first day of the month: the month's photos", or a saved slideshow / album / person.
  - Delivery: a **small notification** at that time ("Your Sunday slideshow is ready"); tapping it opens the app, which builds and plays the slideshow then. The app only asks Android to show a notification at a set time (inexact alarm, `flutter_local_notifications`-style scheduling); **no code reads photos or the database in the background**. The next notifications are set again at every launch; after a reboot, the system's boot broadcast re-sets them (`RECEIVE_BOOT_COMPLETED`, a few lines that only re-schedule).
  - Needs the notification permission on Android 13+, asked when the first ritual or the memories notification is turned on, never at onboarding. Without it, memories still show as the card in the app.
- No ads in slideshows, memories or People.
- **Later, kept in mind** (not built now): sharing a slideshow (as a video file), casting to a TV (Chromecast). Saved slideshows are stored so these can be added without changing them.

### Monetization: light ads + "Remove ads" purchase

**Principle: ads must be as unobtrusive as possible.** The app must remain pleasant to use in its free version.

**Allowed ad placements (only these):**
- A small **adaptive banner** at the bottom of the **Folders** tab.
- One **native ad card** in the **Clean** tab, visually integrated between the cleanup cards, styled to match Material 3, and clearly labeled "Ad".

- Added by the product owner on 2026-11-05: one **interstitial before a manual slideshow** (a *Slideshow* button of an album page, a selection, or a period), at most every 5 minutes. Never before a memory, a ritual or a saved slideshow, and never during a slideshow.

**Strictly forbidden:**
- Any other interstitial (full-screen) ad; rewarded ads, video ads, app-open ads.
- Any other ad in the viewer, swipe mode, editor, duplicates screens, trash, onboarding, map, search, settings, People, user albums, slideshows or memories.
- Any ad that shifts the layout unexpectedly (reserve the banner's space to avoid layout jumps).

**Consent (GDPR / EEA):**
- Use the Google **UMP SDK**: request consent information at launch, show the consent form when required, and only initialize and load ads after consent has been resolved.
- If the user declines personalization, serve non-personalized / limited ads.
- A "Privacy & ad choices" entry in Settings reopens the consent form.

**"Remove ads" in-app purchase:**
- A single **non-consumable** in-app product (`remove_ads`), priced at **€4.99** (price configured in the Play Console; always display the localized price returned by the store, never a hardcoded one).
- Purchasing it removes **all** ads immediately and permanently. All features remain free for everyone.
- **Acknowledge** purchases (Google Play refunds unacknowledged purchases after 3 days).
- **Restore purchases**: check existing purchases at every launch and provide a "Restore purchase" button in Settings, so the purchase follows the user's Google account across devices and reinstalls.
- Cache the ad-free status locally (Drift `settings`) so no ad flashes before the store check completes; re-verify with the store at launch.
- When the user is ad-free, do not initialize the ads SDK at all.
- Handle all purchase states (pending, cancelled, error, already owned) with clear messages.

**Where the purchase is offered (no nagging):**
- A "Remove ads — {localized price}" entry in Settings, showing an "Ad-free ✓" state once purchased.
- A small, discreet "Remove ads" link next to the banner.
- At most **once ever**: after a large cleanup (more than 500 MB freed), a gentle bottom sheet: "You just freed 2.3 GB! Enjoying Clean Gallery? Remove ads for {price}." with a "No thanks" option. Never show it again once dismissed.
- No recurring popups, no countdowns, no dark patterns.

**Privacy:**
- Ads SDKs must never receive any media data or metadata.
- Onboarding, About screen and store listing state: "Your photos never leave your device."

**Development and testing:**
- Use Google's **test ad unit IDs** in debug builds; production IDs come from build configuration.
- Use Play Console license testers to test the purchase flow.


### Settings
Trash retention period, duplicate sensitivity (+ advanced mode), time window, People on/off + face grouping sensitivity + delete face data, memories (off / weekly / monthly, day and time, notification), rituals, slideshow defaults and music, screenshot age, large video threshold, remove GPS on share by default, default column count, theme (system / light / dark), language, permission status, re-run analysis, clear cache, "Remove ads" / "Restore purchase", privacy & ad choices (consent form), privacy policy link, about.

## User interface
- **Very simple, modern and intuitive.** Material 3, dynamic colors (Material You), dark mode, rounded corners, subtle and smooth animations.
- Navigation with 3 tabs maximum. Settings and Trash accessible from a top menu.
- Every destructive action shows an **"Undo" snackbar**.
- Polished empty states (illustration + helpful text), skeleton loading states.
- Accessibility: sufficient contrast, dynamic text sizes, screen reader labels, touch targets of at least 48 dp.

## Documentation

Documentation is **part of the work, not an afterthought**. It must be written and kept up to date **during** development, so that a human developer or an AI assistant can pick up the project at any point and understand it quickly.

### Files to create and maintain

    README.md                 project overview, features, setup, build, run, test (for humans first)
    AGENTS.md                 entry point for AI assistants (see below)
    CLAUDE.md                 one line pointing to AGENTS.md (so all AI tools find the same instructions)
    CHANGELOG.md              "Keep a Changelog" format, one section per milestone
    docs/
      README.md               index of all documentation with one-line descriptions
      progress.md             milestone status, what is done, known issues, next steps
      architecture.md         layers, module map, data flow, dependency rules, diagrams
      database.md             schema (tables), indexes, migration history
      analysis-engine.md      algorithms, thresholds and their rationale, performance notes
      platform-android.md     permissions, native Kotlin channel API (methods, arguments, return values, errors)
      monetization.md         ad placements, consent flow, purchase flow and states
      testing.md              test strategy, how to run tests, test fixtures
      release.md              build and signing, Play Console checklist
      features/
        <feature>.md          one file per feature (library, viewer, duplicates, swipe, trash, cleanup, editor, map, search, settings, onboarding, favorites)
      decisions/
        0001-<title>.md       Architecture Decision Records (ADR), one per significant choice

### AGENTS.md content
A concise, AI-oriented guide that must contain:
- A 5-line project summary.
- Essential commands (install, code generation, run, test, lint, build).
- The architecture map: which folder contains what, and where to add new code.
- Coding conventions (naming, state management patterns, error handling, localization).
- **Non-negotiable rules** of the project, for example: never use `MANAGE_EXTERNAL_STORAGE`; every delete goes through the trash; no ads outside the two allowed placements; no media data sent to any SDK; platform code only behind interfaces; update the documentation with every change.
- Links to the relevant files in `docs/` for deeper context.

### Feature file template (`docs/features/<feature>.md`)
Each feature file follows the same structure:
1. **Purpose**: 2–3 sentences.
2. **User flows**: numbered steps, with a Mermaid diagram when the flow has branches.
3. **Screens and widgets**: list with file paths.
4. **State and data**: providers, repositories, database tables involved.
5. **Edge cases and error handling**.
6. **Tests**: what is covered and where.
7. **Known limitations / future work**.

### Writing rules
- Standard Markdown only, rendering correctly on GitHub.
- Each file starts with a short summary paragraph and a line `Last updated: <date> — Milestone <Mx>`.
- Short sections with clear, descriptive headings; one topic per section.
- Use **tables** for schemas, settings, thresholds and permission lists; **Mermaid** diagrams for architecture and flows; code blocks for commands and API signatures.
- Reference code with **relative links to the actual file paths** (e.g. `[duplicate_grouper.dart](../lib/analysis/duplicate_grouper.dart)`).
- **No duplicated information**: each fact lives in one place; other files link to it.
- Explain the **"why"**, not only the "what" (especially for thresholds, algorithms and architectural choices).
- Keep it concise and factual; no filler.
- Public Dart APIs have `///` doc comments; the Kotlin channel methods have KDoc comments.

### Keeping documentation in sync
- Any change to code behavior, schema, settings, permissions or architecture **must update the related documentation in the same commit**.
- A significant technical choice (package selection, algorithm change, deviation from this prompt) gets an ADR in `docs/decisions/`.
- A milestone is **not complete** until `docs/progress.md`, `CHANGELOG.md` and the affected feature files are up to date.

## Out of scope (do not build)
- Locked private folder (planned for v1.1)
- iOS version (planned later, but the architecture must allow it)
- Any AI or machine-learning-based detection, **except on-device face recognition for People** (requested by the product owner on 2026-11-01). Duplicates, blur, Enhance and the scanner stay without machine learning.
- Cloud sync or shared albums
- For now, kept for later: exporting or sharing a slideshow as a video, casting to a TV
- Subscriptions or any paid feature other than "Remove ads"

## Quality
- Comprehensive unit tests on the analysis engine, with a test photo set (exact duplicates, recompressed, resized, bursts, close-but-different photos) and regression tests for false positives.
- Unit tests for the file-name date regexes.
- Unit tests for the purchase state logic (owned, pending, restored, refunded) and for the rule that hides ads when ad-free.
- Widget tests on the main screens, integration tests on the delete and trash flows.
- Performance: 60 fps scrolling with 30,000 media items, no UI freezes during analysis, controlled memory usage (no bulk loading of full-size images). Ads must not degrade scrolling performance.
- GitHub Actions CI: static analysis, tests, APK/AAB build, and a Markdown lint / broken-link check on the documentation.

## Workflow: milestones
Build in this order. **At the end of each milestone, stop** and provide: a summary of what was done, how to test it on a phone, known issues, and the list of documentation files created or updated. Then **wait for my approval** before moving to the next one. Make clear, frequent commits.

**Definition of done for every milestone:** code works, tests pass, lints pass, and documentation (`docs/progress.md`, `CHANGELOG.md`, affected `docs/features/*.md`, and any other impacted file) is up to date.

- **M0 — Foundations**: project setup, architecture, lints, CI, theme, router, Drift database, native Kotlin module, build configuration (debug/release IDs), onboarding and permissions. **Create the full documentation skeleton**: `README.md`, `AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md`, `docs/README.md`, `docs/progress.md`, `docs/architecture.md`, `docs/database.md`, `docs/platform-android.md`, `docs/testing.md`, and the first ADRs for the stack choices.
- **M1 — Navigation**: folders, grid, timeline view, pinch-to-zoom, viewer, video playback.
- **M2 — Actions**: system favorites, sharing (with GPS option), drag-to-select multi-selection, configurable trash with purge, basic settings.
- **M3 — Engine level 1**: incremental indexing, dates, exact duplicates and bursts, virtual folder, comparison screen, batch delete. Create `docs/analysis-engine.md`.
- **M4 — Engine level 2**: perceptual hashes, BK-tree, similar photos, BestPicker, ignored pairs, adjustable thresholds, storage dashboard.
- **M5 — Cleanup**: Clean tab, swipe mode with undo, blurry photos, screenshots, large videos.
- **M6 — Advanced viewer and editing**: translucent info panel, editor, filters.
- **M7 — Exploration**: map, search.
Milestones M8 to M10 were added on 2026-11-01 for the product owner's new features, in this order (approved the same day); monetization and polish move to M11 and M12.

- **M8 — User albums**: app albums (no file ever moved), *Add to album* from the selection bar and the viewer, album pages, rename, cover, delete, *My albums* in the Albums tab. Create `docs/features/user-albums.md`.
- **M9 — Slideshows and memories**: slideshow player and options, music (bundled free tracks or a track from the phone), entry points (album pages, selection, date range), saved slideshows, memories, memory card, Memories list, rituals and the weekly notification without background work. Create `docs/features/slideshow.md` and `docs/features/memories.md`.
- **M10 — People**: model choice (ADR first), opt-in, face scan, grouping, People section and person pages, naming, merging, corrections, Person chip in the search, *Delete face data*. Create `docs/features/people.md` and a *Faces* section in `docs/analysis-engine.md`.
- **M11 — Monetization**: AdMob integration (banner in Folders, native card in Clean tab), UMP consent flow, "Remove ads" in-app purchase with restore, ad-free state, upgrade entry points. Create `docs/monetization.md`.
- **M12 — Polish and release preparation**: performance optimization, accessibility, complete EN/FR translations, app icon, "About" screen, privacy policy link in About and Settings. Create `docs/release.md` with a checklist of everything I need to fill in on the Play Console (store listing, "Contains ads" declaration, Data safety form, content rating, in-app product setup, closed testing requirements). Final documentation review: every file accurate, no broken links.

If a requirement seems technically problematic or ambiguous, flag it and propose a solution **before** implementing it.
