# Release

How to build, sign and publish Clean Gallery: the upload key, the release checklist, GitHub releases, F-Droid, and every Play Console form with the answers to prepare.

Last updated: 2026-11-08 — Milestone M12

Clean Gallery is free software under the GNU GPL v3, with no ads, purchase or tracking ([ADR 0032](decisions/0032-open-source-without-ads.md)). The way to publish is not chosen yet: Play needs 12 testers for 14 days on a personal account, which the product owner cannot gather ([progress.md](progress.md)). GitHub releases and F-Droid need no tester.

## Versions

- The version is in [pubspec.yaml](../pubspec.yaml): `version: 1.0.0+1` is the version name (`1.0.0`, shown in About) and the version code (`1`, which every store needs to grow).
- Every release bumps both: `1.0.1+2`, `1.1.0+3`… The code never goes down and is never reused, even for a release that was withdrawn.
- APKs split per architecture (`--split-per-abi`) get the version code plus 1000 × the ABI number from Flutter (1001 for `armeabi-v7a`, 2001 for `arm64-v8a`, 4001 for `x86_64`), so the APK of each architecture can update itself.

## Upload key

Release builds must be signed with the product owner's own key. Without it, Gradle signs them with the debug key and prints *Clean Gallery: no release key found*; such builds are for testing only: Google refuses them and users could not update them with a properly signed APK.

**The key is the app's identity**: Android only installs an update signed with the same key. If it is lost, the app can never be updated again under the same id (except on Play with Play App Signing, through Google's support). Keep two copies of the `.jks` file and its passwords, outside the repository and outside this machine (a password manager, an encrypted USB key).

### Creating it (once, by the product owner)

In a terminal of your own (the passwords are typed there, never given to the assistant):

```sh
keytool -genkeypair -v \
  -keystore ~/clean-gallery-upload.jks \
  -alias upload \
  -keyalg RSA -keysize 4096 -validity 10000
```

`keytool` asks for a password, then a name (CN) and organization: your name is enough. Use the same password for the key when asked.

Then create `android/key.properties`, which git ignores ([.gitignore](../android/.gitignore)):

```properties
storeFile=/home/<you>/clean-gallery-upload.jks
storePassword=<the password>
keyAlias=upload
keyPassword=<the password>
```

`storeFile` is absolute, or relative to `android/`.

### In CI (optional)

[build.gradle.kts](../android/app/build.gradle.kts) also reads the environment variables `CLEAN_GALLERY_STORE_FILE`, `CLEAN_GALLERY_STORE_PASSWORD`, `CLEAN_GALLERY_KEY_ALIAS` and `CLEAN_GALLERY_KEY_PASSWORD`, for a GitHub Actions job that would build releases from repository secrets. CI does not build signed releases today; local builds are enough for now.

### Checking a build's signature

```sh
~/sdk/android/build-tools/<version>/apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

The `SHA-256` printed must be the same for every release. Write it once in the GitHub release notes, so users can check the APK they download.

## Release checklist

For every release:

1. On `main`, up to date: `flutter analyze` clean, `flutter test` passing, CI green.
2. Bump `version` in `pubspec.yaml` (see [Versions](#versions)).
3. In [CHANGELOG.md](../CHANGELOG.md), rename *Unreleased* to the version and date, e.g. `## [1.0.0] — 2026-11-20`, and start a new empty *Unreleased*.
4. Check [PRIVACY.md](../PRIVACY.md) still matches what the app does; update its date if anything changed (data, network, backup, permissions).
5. Build: `flutter build apk --release --split-per-abi` (GitHub, F-Droid checks) and, for Play, `flutter build appbundle --release`.
6. Check the signature (above), install the arm64 APK on the phone over the previous version (`adb install -r`, it must update without uninstalling) and go through the main screens.
7. Commit (`Release 1.0.0`), tag `v1.0.0`, push the commit and the tag.
8. Publish on the chosen channels (below).

## GitHub releases

The simplest way, available as soon as the repository is public.

1. On GitHub: *Releases* → *Draft a new release* → choose the tag `v1.0.0`.
2. Title `Clean Gallery 1.0.0`; notes: the version's CHANGELOG section, the signing certificate's SHA-256, and which APK to take (*arm64-v8a* for almost every phone since 2017; *armeabi-v7a* for old 32-bit phones).
3. Attach `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk` and `app-x86_64-release.apk`, renamed `clean-gallery-1.0.0-arm64-v8a.apk`, etc., and a `SHA256SUMS.txt` (`sha256sum *.apk > SHA256SUMS.txt`).
4. Users install the APK after allowing their browser or file manager to install apps. Updates: same steps; Android updates the app in place because the key is the same. [Obtainium](https://github.com/ImranR98/Obtainium) can follow the releases for them.

## F-Droid

F-Droid builds the app itself from the source, so its requirements are about the code:

| Requirement | State |
| --- | --- |
| Free license | GPL v3 ✓ |
| Only free dependencies, no Google Play Services, Firebase, ads or analytics | ✓, checked on 2026-11-08 (Dart packages and the Gradle release classpath; a test forbids ad and tracking SDKs) |
| Public source repository, with a tag per release | To do: make the repository public |
| Store texts and images in the repository | [fastlane/metadata/android/](../fastlane/metadata/android/) holds the titles and descriptions in English and French; screenshots to add (see [Store listing](#store-listing)) |
| Anti-features | None expected. The map loads OpenStreetMap tiles, a free network service (no *NonFreeNet*) |

Two ways in:

- **[IzzyOnDroid](https://apt.izzysoft.de/fdroid/)**, a separate F-Droid repository: it takes the signed APKs of the GitHub releases as they are, so updates come from your own key. Ask by opening an issue on its GitLab with the repository link. Fast, usually days.
- **The main F-Droid repository**: open a merge request on [fdroiddata](https://gitlab.com/fdroid/fdroiddata) with a `metadata/com.bichoumac.clean_gallery.yml` file (categories *Gallery* and *Multimedia*, license `GPL-3.0-only`, source, issues, the build recipe with the Flutter version, auto-update on tags). F-Droid then signs the app with its own key, so the F-Droid and GitHub APKs cannot update each other, unless the build is reproducible and F-Droid publishes the developer's signature. Reviews take weeks. F-Droid's maintainers help write the recipe for Flutter apps.

## Google Play

On hold: a personal account must run a closed test with at least 12 testers for 14 days in a row before it can publish. Without ads or purchase, nothing else ties the app to Play. If it is chosen later, the forms below are what the Play Console asks for.

### Account and app

1. Finish the developer account's identity checks.
2. *Create app*: name *Clean Gallery*, default language, *App*, *Free*, accept the declarations. The application id `com.bichoumac.clean_gallery` is final (2026-11-05) and set by the first upload.
3. **Play App Signing**: accept it; the key above becomes the *upload key*, and Google keeps the app's signing key. Losing the upload key is then recoverable through Google's support; APKs installed from GitHub are signed with a different key and cannot be updated by Play (and the reverse).
4. **Testing**: *Closed testing* track with at least 12 testers opted in for 14 days in a row, then *Apply for production*.

### App content (Policy → App content)

| Form | Answer |
| --- | --- |
| Privacy policy | The public URL of [PRIVACY.md](../PRIVACY.md): `https://github.com/Bichoumac/Clean-Gallery/blob/main/PRIVACY.md` once the repository is public, or the Google Sites page once updated to match it |
| Ads | **No, my app does not contain ads** |
| App access | All functionality is available without special access (no account, no login) |
| Content rating | IARC questionnaire, category *Utility, productivity, communication or other*: no violence, sexuality, language, controlled substances, gambling; **users cannot interact or share content with each other** (sharing goes through Android's share sheet to other apps); no location shared with other users. Expected: *Everyone* / *PEGI 3* |
| Target audience | 13 and over, or 18 and over. Not under 13: choosing children brings in the Families policy, which the app was not reviewed for |
| News app | No |
| Government app, financial features, health | No |
| Data safety | See below |
| Photo and video permissions | See below |

### Data safety

The answers follow what the app does ([PRIVACY.md](../PRIVACY.md), [platform-android.md](platform-android.md#android-backup)):

- **Does your app collect or share any of the required user data types?** No.
  - Photos, videos and their metadata are read and analyzed on the phone only; nothing is sent to the developer or anyone else. Sharing happens only when the user picks an app in Android's share sheet, which Play does not count as the developer's collection.
  - **Map**: the tiles come from OpenStreetMap's servers, which receive the device's IP address and the area being shown, not the photos or their locations as data. Play's guidance on network requests to a third party should be read again when filling the form; if it is judged to be sharing, declare *Approximate location*, shared, not collected by the developer, for app functionality, optional (the map is only used when opened).
  - **Android backup**: the app's database (settings, analysis results, user albums) can be copied by Android's own backup to the user's Google account, end-to-end encrypted on Android 9+. This is the system's feature, not the developer's collection. Check Play's current help on backups when filling the form.
  - **Face data**: People (M10) is postponed; nothing to declare. If it is built, its measurements stay on the phone ([ADR 0029](decisions/0029-face-model.md)) and the answers are reviewed then.
- **Is all user data encrypted in transit?** Map tiles use HTTPS.
- **Do you provide a way for users to request deletion?** No data is collected; uninstalling the app or clearing its storage removes everything it stored.

### Photo and video permissions

Since 2025, apps holding `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` must declare why. Clean Gallery is a gallery: browsing, organizing and cleaning the whole library is its core purpose, which the policy allows. In the declaration, describe that core use and give a short video of the app showing the library, duplicates and the trash.

`MANAGE_MEDIA` (optional *Media management*, to skip Android's confirmation on each deletion) is still an open question for Play ([ADR 0006](decisions/0006-permissions.md)); the app works without it. If Play refuses it, remove it from the manifest for the Play build.

### Store listing

Shared with F-Droid and the GitHub page; the texts are in [fastlane/metadata/android/](../fastlane/metadata/android/).

| Item | Limit | Content |
| --- | --- | --- |
| App name | 30 characters | Clean Gallery |
| Short description | 80 characters | `short_description.txt` |
| Full description | 4,000 characters | `full_description.txt` |
| App icon | 512 × 512 PNG | [design-assets/](design-assets/) |
| Feature graphic | 1024 × 500 | To make, from the rosace and the palette ([design.md](design.md)) |
| Phone screenshots | 2 to 8, 16:9 or 9:16 | **By the product owner**, on a phone with photos they are fine to show (the assistant never takes screenshots of the phone). Suggested: a timeline, the viewer, duplicates, swipe sorting, Stats, the map. Put them in `fastlane/metadata/android/en-US/images/phoneScreenshots/` as `1.png`, `2.png`… |
| Category | | Photography |
| Contact e-mail | | <bichoumac.dev@gmail.com> |

Target API level: Play requires apps to target a recent Android version; `targetSdk` is 36 in [build.gradle.kts](../android/app/build.gradle.kts). Check the requirement of the year before each upload.
