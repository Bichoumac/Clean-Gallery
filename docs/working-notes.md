# Working notes

How the product owner and the AI assistant work together on Clean Gallery, the constraints of the development machine, and where to pick up. Read it at the start of every session, after [AGENTS.md](../AGENTS.md).

Last updated: 2026-10-29 — Milestone M6

## Where to pick up

Quick resume (keep this short; history is in [progress.md](progress.md) and git):

- **Branch `m6-viewer`** (M6, advanced viewer and editing). Pushed up to `a1cf8f4` (2026-10-28); later commits are local until the product owner asks to push. No PR yet: it comes at the end of M6 (title and description in a text file, link `https://github.com/Bichoumac/Clean-Gallery/pull/new/m6-viewer`).
- **Done in M6**, all on this branch: info panel (mini map, quality row), stacks of duplicates in the timelines, map and mini map (brought forward from M7), viewer group strip (Keep / Trash), sort by number of duplicates, viewer actions at the bottom, **editor** (crop, straighten, rotate, flip, Enhance, adjustments, vignette, pencil, blur, pixelate, texts, Before/After, save as copy or replace) and **document scanner**. Feature docs: [editor.md](features/editor.md), [scan.md](features/scan.md), [map.md](features/map.md), [viewer.md](features/viewer.md).
- **Blur/pixelate fix** (2026-10-29): reported as covering the whole photo, fixed with a clip, reinstalled; to confirm (item 57).
- **Confirmed on the phone**: items 1 to 36 of [testing.md](testing.md#m6--viewer-and-editing-to-verify-on-a-device). **Waiting for the product owner's results**: items 45 to 64 (editor with save, pencil, texts, scanner), installed on 2026-10-29. Record them in testing.md and progress.md first.
- **Next**: part 3, filters (about ten presets, each a color matrix composed with the adjustments, thumbnails of the photo with each). Then end of M6: CHANGELOG section, PR file, README status. Batch editing: not wanted (2026-10-29). Scanner: from photos only, no camera.
- **Key design points to keep**: one paint function (`paintEdit`, `paintPage`) for preview and saving; the native side only writes JPEG + EXIF (`PhotoSaver.kt`); every delete through the app trash; pure Dart in `lib/analysis/` and `lib/domain/`.
- **Commands that save tokens**: run tests to a file and read only the summary, e.g. `flutter test --timeout 60s > /tmp/…/t.log 2>&1; tail -1 …` (piping into `grep` hides progress until the end); widget tests that decode images need `tester.runAsync` (see `waitUntil` in [scan_test.dart](../test/features/scan/scan_test.dart)); never `pkill -f` a pattern that appears in your own command line.

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
| Phone | Samsung Galaxy A54, Android 16, French. Its USB device needs `sudo setfacl -m u:claude:rw /dev/bus/usb/<bus>/<device>` (from `lsusb`); the access is lost when the phone is unplugged or the session resets. The screen locks after 30 s; ask before changing that setting. |
| CPU throttling | On 2026-10-26/27 the CPU ran at 600 MHz (`grep MHz /proc/cpuinfo`) instead of up to 3.1 GHz: `flutter test` took about 3 minutes instead of 1, benchmarks varied by 2×. A Gradle daemon left running also filled the swap; stop it after builds (`android/gradlew --stop`). |
| Benchmarks | Pure Dart code of `lib/analysis/` can be timed AOT without a device: `dart compile exe -p .dart_tool/package_config.json <script>` from the project root, script in the scratchpad. `flutter test` runs JIT and gives misleading numbers. |
| Speed tests | Always on a release build (`flutter build apk --release --target-platform android-arm64`); debug builds are several times slower and were judged unusable. |
| System packages | Avoid installing new system packages when a workaround exists (an `apt install` was declined once). |
| Docs lint | `markdownlint-cli2` 0.18.1 and `lychee` (offline) as in CI; portable copies of Node.js and `lychee` were downloaded to the assistant's temporary folder and may need downloading again. |
| Tests | `flutter test --timeout 60s`; app-level widget tests use `testApp` and `pumpTestApp` ([testing.md](testing.md)). |
