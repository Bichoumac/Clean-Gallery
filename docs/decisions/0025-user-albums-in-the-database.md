# ADR 0025 — User albums in the database, never as folders

Why the albums the user creates are lists in the app's database instead of folders on the device.

Last updated: 2026-11-01 — Milestone M8

- **Status**: Accepted by the product owner on 2026-11-01
- **Date**: 2026-11-01

## Context

The product owner asked for albums the user creates, to add photos to a new or an existing album. On Android a "real" album is a folder: MediaStore groups media by `BUCKET_ID`, the folder of the file. Making an album visible to every gallery app means moving the files into `Pictures/<Album>/` (a MediaStore write request, one system confirmation per batch, none with "Media management") or copying them.

The product owner chose on 2026-11-01: "The app moves no file, so if an album is deleted or the app is uninstalled, the photo is not deleted."

## Decision

- An album is a row of `user_albums`; its items are rows of `user_album_items` (album id, MediaStore id, date added). **No file is ever moved, copied or deleted** for an album.
- An album page is a `MediaSelection(userAlbumId: …)`: one more condition in the index query, so albums get every timeline feature for free.
- `user_album_items.asset_id` is not a foreign key to `assets`: items that leave the index without leaving the device (limited access, rebuilt index) stay in their albums. Items deleted for good are removed explicitly.

## Alternatives considered

- **Moving files into folders**: visible in every gallery app and kept after uninstalling, but a photo could be in one album only, camera photos would leave the Camera tab, and every change would need a system confirmation without "Media management". Refused by the product owner.
- **Copying files**: doubles the space taken and creates the exact duplicates the app itself reports.

## Consequences

- Albums exist only in Clean Gallery and are lost when the app is uninstalled; the photos are untouched in both cases.
- A photo can be in any number of albums at no cost.
- No permission and no system prompt are needed to create, fill or delete an album.
