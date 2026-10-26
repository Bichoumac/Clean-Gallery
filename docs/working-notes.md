# Working notes

How the product owner and the AI assistant work together on Clean Gallery, the constraints of the development machine, and where to pick up. Read it at the start of every session, after [AGENTS.md](../AGENTS.md).

Last updated: 2026-10-26 — Milestone M3

## Where to pick up

- The milestone status lives in [progress.md](progress.md); this section only says what to do first.
- End of 2026-10-26: M0 to M2 are merged into `main`. M3 is complete on branch `m3-engine` and tested on the phone, except *Analyze the library again* (item 26 of [testing.md](testing.md#m3--bursts-to-verify-on-a-device)); the pull request is to open.
- **First**: `git fetch` and check whether `m3-engine` is merged and whether CI passed; then branch `m4-…` from an up-to-date `main`.
- **Next**: M4, similar photos: perceptual hashes on thumbnails in a Dart isolate, BK-tree, union-find groups in a "Similar photos" section, "Not duplicates" (ignored pairs), sensitivity presets in Settings, storage dashboard.

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
| Speed tests | Always on a release build (`flutter build apk --release --target-platform android-arm64`); debug builds are several times slower and were judged unusable. |
| System packages | Avoid installing new system packages when a workaround exists (an `apt install` was declined once). |
| Docs lint | `markdownlint-cli2` 0.18.1 and `lychee` (offline) as in CI; portable copies of Node.js and `lychee` were downloaded to the assistant's temporary folder and may need downloading again. |
| Tests | `flutter test --timeout 60s`; app-level widget tests use `testApp` and `pumpTestApp` ([testing.md](testing.md)). |
