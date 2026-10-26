# ADR 0017 — Exact duplicates with SHA-256 on size collisions

How exact duplicates are found, and why the content hash is SHA-256 instead of the brief's xxHash.

Last updated: 2026-10-26 — Milestone M3

- **Status**: Accepted (proposed to the product owner before implementation, 2026-10-26)
- **Date**: 2026-10-26

## Context

The brief: "Exact duplicates: same size, then same xxHash of the content." Hashing means reading every byte of a file, which is the expensive part: a library of 30,000 items can hold 100 GB. xxHash is not part of Android or Dart; it would need a native library or a Dart package, and hashing in Dart would mean copying every file over the platform channel.

## Decision

- **Only items that share their size with another item are hashed.** Two files of different sizes cannot be identical, and the size is in the index. In a typical library, few items qualify.
- **SHA-256 in Kotlin** (`MessageDigest`, part of Android), reading each file once in 1 MB blocks through its Images or Video URI, on a thread of its own so index syncs and favorite requests never wait behind a large video ([MediaIndex.kt](../../android/app/src/main/kotlin/com/bichoumac/clean_gallery/MediaIndex.kt)).
- **Incremental and resumable**: hashes are saved every 20 files in `assets.content_hash` and kept until the file changes (modification date or size); an interrupted scan resumes where it stopped. Unreadable files get an empty hash so they are not retried until they change.
- **Groups are rebuilt** after each scan from the stored hashes (`duplicate_groups` of kind `exact`), with the suggested item to keep. Screens filter them by folder and leave trashed items out ([duplicates.md](../features/duplicates.md)).

## Alternatives considered

- **xxHash (XXH3) through a native library**: about 5 to 10 times faster to compute than SHA-256 in software, but reading the file dominates: on recent phones, SHA-256 uses the ARMv8 cryptography instructions and runs at roughly the speed storage can be read, so a faster hash would barely shorten a scan. A new native dependency is not worth it.
- **Hashing in Dart** (`package:crypto` or an xxHash package): every byte would cross the platform channel, or files would be opened through paths the app does not own on Android 11+.
- **Hashing only the first and last megabytes**: much faster on videos, but two different files with the same size, start and end (e.g. recordings with a fixed header) would be reported as identical. The brief asks for certain duplicates.

## Consequences

- No new dependency; the hash is the same on every device.
- A library with many large same-size videos takes longer on its first scan; later scans read only new files.
- If the size check turns out too weak on some libraries (many same-size files), a partial hash on the first megabyte can be added as a middle step without changing the stored hash.
