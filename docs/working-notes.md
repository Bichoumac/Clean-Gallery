# Working notes

How the product owner and the AI assistant work together on Clean Gallery, the constraints of the development machine, and where to pick up. Read it at the start of every session, after [AGENTS.md](../AGENTS.md).

Last updated: 2026-10-28 — Milestone M6

## Where to pick up

- The milestone status lives in [progress.md](progress.md); this section only says what to do first.
- End of 2026-10-27: M0 to M3 are merged into `main` (M3 as PR #4). M4 is on branch `m4-similar` (committed locally, not pushed).
- **M4 device tests (2026-10-27)**: the first found no similar groups; after the fixes (commit `d07c2fd`) the second confirmed similar groups, progress, resume, Not duplicates, sensitivity and Stats rows. Decisions A (multi-index hashing, ADR 0019) and B (keep the pre-selection) are approved. Results in [testing.md](testing.md#m4--similar-photos-and-stats-to-verify-on-a-device).
- **Chips on the duplicates screen** (All, Identical copies, Bursts, Similar photos) added at the product owner's request, Stats split the same way; to check on the phone.
- **Checked on 2026-10-27**: chips clearer, WhatsApp copy grouped with its original marked Best, cleaning from Stats, viewer sharp at once (previews now decoded from the file: MediaStore's cache stops at 512 px on this phone). Then pinch zoom, items 9, 10 and 13 (*Analyze the library again*): the whole M4 checklist is confirmed.
- **Measuring on the phone**: the product owner allowed reading `logcat` lines that hold only durations and sizes, logged under one tag by temporary code that is never committed. Ask again for each new measurement.
- **Product owner's request**: stack similar photos in the timelines. Built on 2026-10-28, before the editor, at the product owner's request: all groups stack, a tap unfolds in place.
- M4 merged into `main` (PR #5) on 2026-10-27, after a CI fix (the runner's disk was full; the build job now frees space first).
- **M5 on branch `m5-cleaning`**, in three parts tested one by one on the phone: 1. old screenshots and large videos (confirmed on the phone); 2. blurry and dark photos, one pass on 256-pixel thumbnails (product owner's choice; done, to test); 3. swipe mode, oldest first (product owner's choice; done, to test). On 2026-10-27 the product owner asked to build the rest of M5 in one go, push, and send one report of what to test. See [progress.md](progress.md#m5--cleanup).

- M5 merged into `main` (PR #6) on 2026-10-27. Device test: all good except some **hazy night photos with lights listed as blurry**. Calibrated on 2026-10-27 from measures shown by a temporary build (never committed) in the info panel: low sharpness and low relative sharpness mean real blur; the product owner set the hazy threshold at 150 ([ADR 0021](decisions/0021-hazy-photos-are-not-blurry.md)).
- **M6 on branch `m6-viewer`, pushed on 2026-10-28**: part 1 (info panel) and the hazy photo rule confirmed on the phone; the quality row added at the end of the session (not seen on the device yet). **2026-10-28: stacks in the timelines and the map** (brought forward from M7) added first, both at the product owner's request (to test on the phone, [testing.md](testing.md#m6--viewer-and-editing-to-verify-on-a-device) items 11 to 25), then the viewer's group strip with Keep and Trash (items 26 to 31). **Next: part 2, the editor**; the detailed plan is in [progress.md](progress.md#next-steps) (M6 → Next steps). No pull request yet: it comes at the end of M6.

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
