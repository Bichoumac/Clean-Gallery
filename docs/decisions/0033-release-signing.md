# ADR 0033 — Release signing from a key outside the repository

How release builds are signed while the repository is public.

Last updated: 2026-11-08 — Milestone M12

- **Status**: Accepted
- **Date**: 2026-11-08

## Context

Release builds were signed with the debug key, which stores refuse and which would make every later update impossible to install over them. The repository is public (GPL v3, [ADR 0032](0032-open-source-without-ads.md)), so the key and its passwords can never be in it (AGENTS.md rule 7). The way to publish is not chosen yet: GitHub releases, IzzyOnDroid and Play all need APKs signed with the product owner's key; the main F-Droid repository signs with its own.

## Decision

- [build.gradle.kts](../../android/app/build.gradle.kts) defines a `release` signing config from `android/key.properties` (git-ignored) or, failing that, from the `CLEAN_GALLERY_STORE_FILE`, `CLEAN_GALLERY_STORE_PASSWORD`, `CLEAN_GALLERY_KEY_ALIAS` and `CLEAN_GALLERY_KEY_PASSWORD` environment variables, for a CI job later.
- Without either, release builds still fall back to the debug key, with a Gradle warning, so `flutter run --release` and CI's release build keep working for anyone who clones the repository.
- The product owner creates the key on their own machine and keeps two copies; the assistant never sees the passwords ([release.md](../release.md#upload-key)).

## Consequences

- One key for GitHub releases, IzzyOnDroid and, as the upload key, Play (with Play App Signing).
- A build signed with the debug key can be mistaken for a release; the warning and the signature check of the release checklist cover it.
- Losing the key means the app can never be updated outside Play; this is written in [release.md](../release.md#upload-key).
