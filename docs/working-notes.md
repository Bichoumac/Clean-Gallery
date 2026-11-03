# Working notes

How the product owner and the AI assistant work together on Clean Gallery, the constraints of the development machine, and where to pick up. Read it at the start of every session, after [AGENTS.md](../AGENTS.md).

Last updated: 2026-11-04 — Milestone M9

## Where to pick up

Quick resume (keep this short; history is in [progress.md](progress.md) and git):

- **M6 is merged**, filters included (PRs #7 and #8, 2026-10-30). **M7 search is merged** (PR #9, 2026-10-30), everything confirmed on the phone (items 71 to 83 of [testing.md](testing.md#m7--search-to-verify-on-a-device), [search.md](features/search.md)).
- **Everything built in M6 is confirmed on the Galaxy A54** (items 1 to 64 of [testing.md](testing.md#m6--viewer-and-editing-to-verify-on-a-device)): info panel with mini map, stacks of duplicates in the timelines, map (brought forward from M7), viewer group strip (Keep / Trash), sorts by number of duplicates, viewer actions at the bottom, editor ([editor.md](features/editor.md)), document scanner ([scan.md](features/scan.md)).
- **Left from M6**: nothing. Not wanted for now: batch editing; scanner camera capture.
- **M8 user albums is merged** (PR #10, 2026-11-01).
- **M9 slideshows and memories** is on branch `m9-slideshows-memories`, reported working on the phone ("ça marche bien", 2026-11-04) and pushed on 2026-11-04; the product owner opens the pull request. First ask whether it was merged; if merged, start **M10 People** from `main` (spec in [prompt.md](../prompt.md); an ADR on the face model comes first). Open point: the product owner picks 2 or 3 CC0 tracks for the bundled music ([slideshow.md](features/slideshow.md#music)).
- **Next milestones**: M10 People, M11 monetization, M12 polish ([progress.md](progress.md)).
- **Phone over USB**: the laptop's webcam is a Xiaomi USB device too; run `p.sh` only once the phone shows in `lsusb` (Samsung, MTP mode), or it may pick the webcam.
- **Key design points to keep**: one paint function (`paintEdit`, `paintPage`) for preview and saving; the native side only writes JPEG + EXIF (`PhotoSaver.kt`); every delete through the app trash; pure Dart in `lib/analysis/` and `lib/domain/`; on the phone (Impeller), avoid blend-mode masks in layers, use clips (blur bug of 2026-10-29).
- **Commands that save tokens**: run tests to a file and read only the summary (`flutter test --timeout 60s > <scratchpad>/t.log 2>&1; tail -1 …`; piping into `grep` hides progress until the end); widget tests that decode images need `tester.runAsync` (see `waitUntil` in [scan_test.dart](../test/features/scan/scan_test.dart)); never `pkill -f` a pattern that appears in your own command line; `gh` is installed but not logged in: give the `pull/new/<branch>` link.

## Working with the product owner

- **Language**: replies in French; code, comments and documentation in English.
- **Milestones**: stop at the end of each milestone with a summary, test instructions, known issues and the documentation updated, and wait for approval.
- **Commits**: commit locally as work progresses; push only when asked.
- **Pull requests**: no GitHub CLI or token on the machine. After pushing, give the link `https://github.com/Bichoumac/Clean-Gallery/pull/new/<branch>` and write the title and description to a text file the product owner can display with `! cat <path>`.
- **Device tests**: the product owner tests on their own phone and reports back. Give a short numbered checklist with the expected result of each item, then record the results in [testing.md](testing.md) and [progress.md](progress.md), separating confirmed items from untested ones.
- **Design**: the product owner wants a distinctive look, not stock Google apps, without clutter ([design.md](design.md), [ADR 0008](decisions/0008-navigation-and-visual-identity.md)).
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
