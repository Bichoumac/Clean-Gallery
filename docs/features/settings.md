# Settings

The Settings tab: display, trash, cleanup, sharing, slideshows and memories, analysis and permissions. The rest of the brief's settings arrive with the features they control.

Last updated: 2026-11-05 — Milestone M11

## Purpose

Let the user choose how the app looks and behaves, and see and change its permissions. Every setting is saved at once in the `settings` table and read before the first frame, so the theme and language are right from launch.

## User flows

1. **Settings tab** (last icon of the bar).
2. Change a setting: it applies immediately and is saved.
3. **Permissions**: each row shows the current status; *Change* opens the system prompt or settings; the status refreshes when the user comes back to the app.

## Settings

| Section | Setting | Values | Default | Applies to |
| --- | --- | --- | --- | --- |
| Display | Theme | System / Light / Dark | System | Whole app |
| Display | Language | System / English / Français | System | Whole app |
| Display | Grid columns at launch | 2–6 | 4 | Every grid, at launch and immediately |
| Display | Corrected dates | On / Off | On | Sort, group, filter and date of every timeline: the date the photo was taken (metadata, then file name) or Android's date ([analysis-engine.md](../analysis-engine.md#capture-date)) |
| Trash | Keep deleted items for | 1–90 days | 30 | Items trashed afterwards |
| Cleanup | Screenshots count as old after | 7 d / 30 d / 90 d / 1 yr | 30 days | The Old screenshots list and its Stats row ([cleanup.md](cleanup.md)) |
| Cleanup | Videos count as large from | 50 / 100 / 250 / 500 MB | 100 MB | The Large videos list and its Stats row |
| Sharing | Remove location when sharing | On / Off | On | Default of the share sheet switch |
| Slideshows and memories | Memories | Off / Every week / Every month | Every week | Off hides the memory card and stops its notification ([memories.md](memories.md)) |
| Slideshows and memories | Notification | On / Off, then day and time | Off; Sunday (or the 1st) at 19:00 | Turning it on asks for the notification permission (Android 13+); refused, it stays off |
| Slideshows and memories | Rituals | Page | — | Recurring slideshows with their notifications ([memories.md](memories.md#user-flows)) |
| Slideshows and memories | Slideshow defaults | Options sheet | 5 s, slow zoom, by date, videos, skip duplicates and blurry, no music | The options proposed before each slideshow; also saved by every *Start* ([slideshow.md](slideshow.md)) |
| Analysis | Similar photos | Low / Medium / High | Medium | How eager the similar photo search is; changing it regroups at once from the stored hashes ([analysis-engine.md](../analysis-engine.md#sensitivity)) |
| Analysis | Advanced mode | On / Off, then three sliders | Off | On: no preset selected; *Any date: difference up to* (strict, 0–10 of 64), *Taken close in time: difference up to* (loose, 0–20 of 64), *Close in time means within* (0–60 seconds). Starts from the preset in use; off returns to Medium. Saved when the finger is lifted |
| Analysis | Analyze the library again | Button | — | Forgets dates, burst ids, content and perceptual hashes and duplicate groups, then syncs and scans again; a spinner and "Analyzing: N of M items" show while it runs. Media, trash, settings and pairs marked "Not duplicates" are kept |
| Permissions | Photos and videos | Allowed / Some items only / Not allowed | — | Read-only status + *Change* |
| Permissions | Location in photos | Allowed / Not allowed | — | Read-only status + *Change* |
| Permissions | Media management | Allowed / Not allowed | — | Read-only status + *Change* |

The sort order of each tab and album is also saved (see [library.md](library.md#sorting-and-date-filter)); the date filter is not, since presets such as "Last 7 days" would become stale.

Still to come, from the brief: clear cache (merged into *Analyze the library again*: the app's only cache is the media index; thumbnails come from Android's own cache).

## Look

Cards with 18 dp padding, a Bricolage title, the retention value in the accent. [Mockup](../design-assets/mockups/screens/15-settings.png).

## Screens and widgets

| Widget | File |
| --- | --- |
| `SettingsScreen` and its sections | [settings_screen.dart](../../lib/features/settings/settings_screen.dart) |
| `MemoriesSettings` (Slideshows and memories) | [memories_settings.dart](../../lib/features/memories/memories_settings.dart) |

## State and data

| Item | File | Role |
| --- | --- | --- |
| `AppSettings` | [app_settings.dart](../../lib/core/settings/app_settings.dart) | Immutable settings with defaults and limits. |
| `AppSettingsController` | [settings_controller.dart](../../lib/core/settings/settings_controller.dart) | Current settings; each setter saves to the database. |
| `initialAppSettingsProvider` | same | Settings read in `main()` before the first frame. |
| `SettingsRepository.loadAppSettings` | [settings_repository.dart](../../lib/core/database/settings_repository.dart) | Reads every key; invalid values fall back to defaults. |
| `permissionStatusProvider` | [settings_screen.dart](../../lib/features/settings/settings_screen.dart) | Permission levels, refreshed on resume. |

Keys are listed in [database.md](../database.md#settings).

## Edge cases and error handling

- **Invalid stored value** (e.g. retention 500, a strict threshold above 10): the default is used.
- **Permission changed in the system settings**: the status refreshes when the app resumes.
- **Language "System" with an unsupported system language**: English.

## Tests

- [app_settings_test.dart](../../test/core/settings/app_settings_test.dart): defaults, stored values, invalid values, similarity settings, sort encoding, view keys.
- [settings_screen_test.dart](../../test/features/settings/settings_screen_test.dart): theme, language, default columns, sensitivity and advanced mode, permission statuses, sort saved and restored.

## Known limitations / future work

- Settings of later milestones (see above).
