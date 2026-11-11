# Working notes

How the product owner and the AI assistant work together on Clean Gallery, the constraints of the development machine, and where to pick up. Read it at the start of every session, after [AGENTS.md](../AGENTS.md).

Last updated: 2026-11-11 — Issue #19

## Where to pick up

Quick resume (keep this short; history is in [progress.md](progress.md) and git):

- **M6 is merged**, filters included (PRs #7 and #8, 2026-10-30). **M7 search is merged** (PR #9, 2026-10-30), everything confirmed on the phone (items 71 to 83 of [testing.md](testing.md#m7--search-to-verify-on-a-device), [search.md](features/search.md)).
- **Everything built in M6 is confirmed on the Galaxy A54** (items 1 to 64 of [testing.md](testing.md#m6--viewer-and-editing-to-verify-on-a-device)): info panel with mini map, stacks of duplicates in the timelines, map (brought forward from M7), viewer group strip (Keep / Trash), sorts by number of duplicates, viewer actions at the bottom, editor ([editor.md](features/editor.md)), document scanner ([scan.md](features/scan.md)).
- **Left from M6**: nothing. Not wanted for now: batch editing; scanner camera capture.
- **M8 user albums is merged** (PR #10, 2026-11-01).
- **M9 slideshows and memories is merged** (PR #11, 2026-11-04). 
- **Visual refresh is merged** (PR #13); the 22 checks of [testing.md](testing.md#visual-refresh--to-verify-on-a-device) were not reported one by one.
- **M10 People is postponed** (product owner, 2026-11-05): licensing risk on every face model found, see [ADR 0029](decisions/0029-face-model.md).
- **Publishing**: GitHub releases only (product owner, 2026-11-11); IzzyOnDroid dropped, as its policy rejects apps written with generative AI. Play stays blocked (personal account, 12 testers for 14 days).
- **M11 monetization was merged** (PR #14, 2026-11-08), **then removed the same day**: the app goes open source without ads ([ADR 0032](decisions/0032-open-source-without-ads.md)). Page transitions (PR #15) and the removal (PR #16) are merged into `main`.
- **M12 is merged** (PR #17, 2026-11-09) and the repository is public. **1.0.0** is prepared on branch `release-1.0.0`: the product owner merges it, the tag `v1.0.0` goes on that commit, then the GitHub release with the signed split APKs and `SHA256SUMS.txt`, then the IzzyOnDroid request. Next releases follow [release.md](release.md#release-checklist).
- **After 1.0.0** (2026-11-11): branch `fix-issue-19` fixes the sliders, widens the similar photo presets, adds the duplicate period and sharpens thumbnails: all of issue #19 ([progress.md](progress.md#issue-19-and-blurry-thumbnails)), waiting for the phone checks and a PR. Issue #20 (network shares) is open, not started.
- **Signing on this machine**: `android/key.properties` and the key belong to user `claude` (the product owner created them with `sudo`, then `chown`); never print or read them, Gradle reads them. Files the product owner copies as root (screenshots…) need `sudo chown -R claude:claude` before the assistant can rename them.
- **1.1.0** released on 2026-11-11 (issue #19, sharp thumbnails, editor colors), on GitHub releases, the only channel ([release.md](release.md)).
- **App on the phone** (2026-11-11): a release build signed with the upload key, so `adb install -r` of a release build keeps its data. A debug build no longer installs over it (different signature): it would need an uninstall, which erases the app's data (settings, albums, trash list, analysis; never the photos).
- **Phone over USB**: the laptop's webcam is a Xiaomi USB device too; run `p.sh` only once the phone shows in `lsusb` (Samsung, MTP mode), or it may pick the webcam.
- **Key design points to keep**: one paint function (`paintEdit`, `paintPage`) for preview and saving; the native side only writes JPEG + EXIF (`PhotoSaver.kt`); every delete through the app trash; pure Dart in `lib/analysis/` and `lib/domain/`; on the phone (Impeller), avoid blend-mode masks in layers, use clips (blur bug of 2026-10-29).
- **Checking a look without the phone**: a temporary widget test can load the real fonts with `FontLoader` and write PNG files with `matchesGoldenFile` and `--update-goldens`; delete it afterwards. Without the fonts, text renders as blocks, which also shows a style that forgot its font family.
- **Commands that save tokens**: run tests to a file and read only the summary (`flutter test --timeout 60s > <scratchpad>/t.log 2>&1; tail -1 …`; piping into `grep` hides progress until the end); widget tests that decode images need `tester.runAsync` (see `waitUntil` in [scan_test.dart](../test/features/scan/scan_test.dart)); never `pkill -f` a pattern that appears in your own command line; `gh` is logged in as the product owner (since 2026-11-11): pull requests, checks, merges and releases can be done with it, when the product owner asks.

## To do next (written 2026-11-05, resume here)

State (2026-11-08): `page-transitions` and `remove-ads` merged into `main` (PRs #15 and #16). M12 on branch `m12-release`. CI no longer uploads builds as artifacts (storage quota). Analyzer clean, all tests pass.

**Decisions waiting for the product owner**

3. **License chosen: GNU GPL v3** (2026-11-08), in `LICENSE`. Make the repository public when the product owner wants; the history was checked on 2026-11-08: only Google's public test ad IDs, no key or password.
4. **How to publish**. Play needs 12 testers for 14 days on a personal account, which the product owner cannot gather. Without ads or billing, GitHub releases (signed APK) and F-Droid need no tester; Play stays possible later through developer exchange communities or an organization account. Paid testers are advised against; fake accounts are out.
5. **Start M12?** Yes, after the page transitions (product owner, 2026-11-08). Needed by every option above.

**Page transitions (branch `page-transitions`, 2026-11-08)**

- Built: tabs slide like a carousel, pages slide over a receding page, tiles grow into their page, predictive back follows the finger, the viewer's photo flies to its own frame ([ADR 0031](decisions/0031-page-transitions.md)). Confirmed on the phone on 2026-11-08.
- Not done: sheets and menus rising with a spring (Material's default kept).

**M12, for the assistant, once approved**

7. Done on `m12-release`: release signing (the product owner creates the key, [release.md](release.md#upload-key)), About and the privacy link (now `PRIVACY.md` on GitHub), `release.md`, store texts, version 1.0.0, accessibility guidelines test.
8. Left: performance pass of the brief (profile build on the phone), final documentation review and link check, the M12 device checks, then the first release on the channels the product owner picks.

**Outside setup, by the product owner**

12. If Play is chosen: finish identity checks, create the app with `com.bichoumac.clean_gallery` (final), internal test. No payments profile or AdMob account is needed any more.
13. Store listing and forms: description, screenshots, content rating, *No ads*, photo and video permissions declaration.

**Privacy policy**

17. Published and public, with the publisher's name and contact, checked on 2026-11-05. Small leftover: the page title is still "Accueil". **To replace by [PRIVACY.md](../PRIVACY.md)**, rewritten on 2026-11-08 without ads or purchase; the product owner updates the Google Sites page. Update its date and text with any change to data, backup or People.

**Still open from before**

18. 2 or 3 CC0 tracks for the bundled music, picked by the product owner.
19. The 22 checks of the visual refresh, never reported one by one.
20. M10 People, postponed: first look for an on-device model whose license allows an open-source app ([ADR 0029](decisions/0029-face-model.md)); without ads, non-commercial licenses may be worth a second look, not settled.

## Working with the product owner

- **Language**: replies in French; code, comments and documentation in English.
- **Milestones**: stop at the end of each milestone with a summary, test instructions, known issues and the documentation updated, and wait for approval.
- **Commits**: commit locally as work progresses; push only when asked.
- **Pull requests**: no GitHub CLI or token on the machine. After pushing, give the link `https://github.com/Bichoumac/Clean-Gallery/pull/new/<branch>` and write the title and description to a text file the product owner can display with `! cat <path>`.
- **Notifications** (product owner, 2026-11-08): send a push notification (`PushNotification`) every time an action of the product owner is needed (plug the phone in, test, decide, push). The tool skips it while the terminal is active, and reaches the phone only through Remote Control.
- **Device tests**: the product owner tests on their own phone and reports back. Give a short numbered checklist with the expected result of each item, then record the results in [testing.md](testing.md) and [progress.md](progress.md), separating confirmed items from untested ones.
- **Design**: the product owner wants a distinctive look, not stock Google apps, without clutter, warm and modern, and a gallery that disappears around the photos ([design.md](design.md), [ADR 0028](decisions/0028-warm-eclat-identity.md)).
- **Notes**: keep notes like these in this file, not in the assistant's private memory.

## Privacy during device tests

- **Never look at the product owner's phone content**: no screenshots (`adb screencap`), no UI dumps, no reading of photos.
- **Ask before reading `logcat`**, even to diagnose a crash: logs can contain file names.
- Installing the app with `adb install` is fine.

This follows the product owner's request and the app's own promise: "Your photos never leave your device."

## Development machine

| Topic | Note |
| --- | --- |
| System | Debian 12, Intel i5-7200U, 7.7 GB RAM. The assistant runs as user `claude`, not the desktop user. |
| SDKs | Flutter in `~/sdk/flutter`, Android SDK in `~/sdk/android`; neither is on `PATH` by default. |
| Gradle memory | Heap set to 3 GB in `android/gradle.properties`; the template's 8 GB was killed by the kernel. Stop the Gradle daemon (`./gradlew --stop`) before running the emulator or the analyzer at the same time. |
| Emulator | Installed (AVD `cg_api34`) but unusable: no GPU access, software rendering too slow. Test on the phone instead. |
| Phone | Samsung Galaxy A54, Android 16, French. Its USB device needs `sudo setfacl -m u:claude:rw /dev/bus/usb/<bus>/<device>`; the access is lost when the phone is unplugged or the session resets. The product owner cannot copy commands from the conversation: ask them to type `sudo sh /home/claude/p.sh` (outside the repository; it finds the Samsung, Google or Xiaomi USB device and runs that `setfacl`). The screen locks after 30 s; ask before changing that setting. |
| CPU throttling | On 2026-10-26/27 the CPU ran at 600 MHz (`grep MHz /proc/cpuinfo`) instead of up to 3.1 GHz: `flutter test` took about 3 minutes instead of 1, benchmarks varied by 2×. A Gradle daemon left running also filled the swap; stop it after builds (`android/gradlew --stop`). |
| Benchmarks | Pure Dart code of `lib/analysis/` can be timed AOT without a device: `dart compile exe -p .dart_tool/package_config.json <script>` from the project root, script in the scratchpad. `flutter test` runs JIT and gives misleading numbers. |
| Speed tests | Always on a release build (`flutter build apk --release --target-platform android-arm64`); debug builds are several times slower and were judged unusable. |
| System packages | Avoid installing new system packages when a workaround exists (an `apt install` was declined once). |
| Docs lint | `markdownlint-cli2` 0.18.1 and `lychee` (offline) as in CI; portable copies of Node.js and `lychee` were downloaded to the assistant's temporary folder and may need downloading again. |
| Tests | `flutter test --timeout 60s`; app-level widget tests use `testApp` and `pumpTestApp` ([testing.md](testing.md)). |
