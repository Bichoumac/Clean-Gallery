# Settings

The Settings tab: display, trash, sharing and permissions. The rest of the brief's settings arrive with the features they control.

Last updated: 2026-10-26 — Milestone M3

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
| Sharing | Remove location when sharing | On / Off | On | Default of the share sheet switch |
| Permissions | Photos and videos | Allowed / Some items only / Not allowed | — | Read-only status + *Change* |
| Permissions | Location in photos | Allowed / Not allowed | — | Read-only status + *Change* |
| Permissions | Media management | Allowed / Not allowed | — | Read-only status + *Change* |

The sort order of each tab and album is also saved (see [library.md](library.md#sorting-and-date-filter)); the date filter is not, since presets such as "Last 7 days" would become stale.

Still to come, from the brief: duplicate sensitivity and time window (M4), screenshot age and large video threshold (M5), re-run analysis and clear cache (M3), "Remove ads" / "Restore purchase" and privacy & ad choices (M8), privacy policy and about (M9).

## Screens and widgets

| Widget | File |
| --- | --- |
| `SettingsScreen` and its sections | [settings_screen.dart](../../lib/features/settings/settings_screen.dart) |

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

- **Invalid stored value** (e.g. retention 500): the default is used.
- **Permission changed in the system settings**: the status refreshes when the app resumes.
- **Language "System" with an unsupported system language**: English.

## Tests

- [app_settings_test.dart](../../test/core/settings/app_settings_test.dart): defaults, stored values, invalid values, sort encoding, view keys.
- [settings_screen_test.dart](../../test/features/settings/settings_screen_test.dart): theme, language, default columns, permission statuses, sort saved and restored.

## Known limitations / future work

- Settings of later milestones (see above).
