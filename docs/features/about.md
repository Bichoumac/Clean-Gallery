# About

The About page and the privacy policy link, under Settings.

Last updated: 2026-11-08 — Milestone M12

## Purpose

Say what the app promises, which version is installed, where its source and privacy policy are, and credit the work it is built on, as the GPL and the licenses of its parts ask.

## User flows

1. **Settings → About** (last section): *Privacy policy* opens the policy in the browser; *About Clean Gallery* opens the page.
2. **About page**: the rosace, *Clean Gallery*, *Version 1.0.0* (the installed version, read from Android), the promise (*Your photos never leave your device…*) and *Free and open source, under the GNU GPL v3 license*.
3. **Links**, each opening the browser: Privacy policy, Source code (GitHub), Report a problem (GitHub issues), License (the GPL text in the repository). When no app can open a link, a snack bar says *No app can open this link.*
4. **Open source libraries**: Flutter's licenses page, with the app's name, version and rosace, listing the license of every package and of the two bundled fonts.
5. **Credits**: map data © OpenStreetMap contributors (opens their copyright page, as the ODbL asks), the Manrope and Bricolage Grotesque fonts (SIL Open Font License), and the bundled music tracks once there are some (`bundledTracks`, [slideshow.md](slideshow.md#music)).

## Screens and widgets

| Widget | File |
| --- | --- |
| `AboutScreen`, `openAppLink`, `appVersionProvider` | [about_screen.dart](../../lib/features/about/about_screen.dart) |
| The About section of Settings | [settings_screen.dart](../../lib/features/settings/settings_screen.dart) |
| `AppLinks`: the web pages the app links to | [app_links.dart](../../lib/core/app_links.dart) |
| `registerFontLicenses`, called in `main` | [font_licenses.dart](../../lib/core/theme/font_licenses.dart) |

Route: `/settings/about` (`AppRoutes.about`).

## State and data

- Links open through `PlatformBridge.openLink` (native `openLink`, an `ACTION_VIEW` intent, https only; [platform-android.md](../platform-android.md#native-channel-clean_galleryplatform)). No browser view inside the app, and nothing about the user is added to the URLs.
- The version comes from `PlatformBridge.appVersion` (native `appVersion`, the installed package's version name), which is `pubspec.yaml`'s `version` ([release.md](../release.md#versions)).
- The font licenses are read from `assets/fonts/*/OFL.txt` only when the licenses page opens; Flutter adds the packages' licenses by itself.
- The privacy policy link is `PRIVACY.md` on GitHub, which needs the repository to be public.

## Tests

- [about_screen_test.dart](../../test/features/about/about_screen_test.dart): Settings opens the privacy policy; About shows the version, promise and license and opens the source and OpenStreetMap pages; the licenses page opens; the fonts are registered.
- [accessibility_test.dart](../../test/accessibility/accessibility_test.dart) checks the page with the other screens.

## Known limitations / future work

- The policy and the links are web pages: without a network, the browser shows its own error.
