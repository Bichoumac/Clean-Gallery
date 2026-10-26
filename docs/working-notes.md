# Working notes

How the product owner and the AI assistant work together on Clean Gallery, the constraints of the development machine, and where to pick up. Read it at the start of every session, after [AGENTS.md](../AGENTS.md).

Last updated: 2026-10-27 — Milestone M4

## Where to pick up

- The milestone status lives in [progress.md](progress.md); this section only says what to do first.
- End of 2026-10-27: M0 to M3 are merged into `main` (M3 as PR #4). M4 is complete on branch `m4-similar` (committed locally, not pushed). The M4 release APK was **installed on the Galaxy A54** on the evening of 2026-10-27 (`adb install -r`, over M3, data kept); the product owner has **not tested it yet**.
- **First, at the start of the next session, ask the product owner these questions again** (they asked for it explicitly), then record the answers in [testing.md](testing.md#m4--similar-photos-and-stats-to-verify-on-a-device) and [progress.md](progress.md):
  1. First analysis: did the app stay fluid while it ran, and roughly how long did it take for how many photos?
  2. Albums → All media → **Duplicates** tile: does it read "N items to review", with a **Similar photos** section?
  3. Is a photo sent to yourself on WhatsApp grouped with its original (original marked **Best**)?
  4. Are two photos of the same scene taken a few seconds apart grouped?
  5. **False positives**: is any similar group made of clearly different photos? (the most important point)
  6. **Not duplicates**: does the group disappear and stay gone after relaunching the app?
  7. Settings → Analysis → Similar photos: fewer groups with Low, more with High? Advanced mode sliders work?
  8. Stats tab: values shown (space you could free, used, photos/videos), and the three rows open the right screens?
  9. Settings → **Analyze the library again** (also M3 item 26): spinner, then the same groups, Not duplicates kept?
  10. Largest font: *Not duplicates* and *Move N to trash* fit or stack, never cut off?
  - **Decision A**: approve [ADR 0019](decisions/0019-similar-photo-search.md) (multi-index hashing instead of the brief's BK-tree, which was slower than brute force), or go back to the BK-tree?
  - **Decision B**: in similar groups, keep pre-selecting every photo but the best (brief), or leave them unselected by default?
- **Next**: push `m4-similar` when asked, open the pull request, then M5 (swipe mode, blurry photos, screenshots, large videos).

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
