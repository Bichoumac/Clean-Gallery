import 'package:clean_gallery/domain/media_item.dart';
import 'package:flutter/widgets.dart';

/// Read access to the device's photos and videos.
///
/// The Android implementation uses MediaStore. The app does not list media
/// through this interface directly: `MediaIndex` copies the library into the
/// database with [snapshot] and [describe], and every list reads the
/// database. Image loading goes through [ImageProvider]s so that Flutter's
/// image cache handles memory and reuse.
abstract interface class MediaSource {
  /// Id and revision of every photo and video, newest first.
  ///
  /// Cheap compared to [describe]: the indexer compares it with the
  /// database and describes only new and changed items.
  Future<LibrarySnapshot> snapshot();

  /// Full metadata of the items with [ids]. Items that no longer exist are
  /// left out.
  Future<List<IndexedMedia>> describe(List<String> ids);

  /// Small square thumbnail of [item], about [size] pixels wide.
  ImageProvider thumbnail(MediaItem item, {required int size});

  /// Screen-sized image of [item], at most [longestSide] pixels on its
  /// longest side, keeping its proportions.
  ///
  /// Rendered by the platform's thumbnail pipeline, so it is much faster
  /// than [fullImage]; the viewer shows it first and loads [fullImage] only
  /// when the user zooms in.
  ImageProvider preview(MediaItem item, {required int longestSide});

  /// Full-resolution image of [item], decoded at most [maxDimension] pixels
  /// on its longest side to bound memory use.
  ImageProvider fullImage(MediaItem item, {int maxDimension = 4096});

  /// Playable URI of a video (a `content://` URI on Android), or `null` if
  /// it cannot be resolved.
  Future<Uri?> videoUri(MediaItem item);
}

/// Every item of the library at one moment, as returned by
/// [MediaSource.snapshot].
final class LibrarySnapshot {
  /// Creates a snapshot.
  const LibrarySnapshot({required this.version, required this.revisions});

  /// Identifier of the platform's media database. It changes when that
  /// database is rebuilt, which can reassign ids: the whole index is then
  /// refreshed.
  final String version;

  /// Revision of each item, by id, newest item first. A revision changes
  /// whenever the item or its metadata (favorite, size, …) changes.
  final Map<String, int> revisions;
}

/// An item with everything the media index stores about it, as returned by
/// [MediaSource.describe].
final class IndexedMedia {
  /// Creates an indexed item.
  const IndexedMedia({
    required this.item,
    required this.albumId,
    required this.albumName,
    required this.revision,
    this.hasMetadataDate = true,
  });

  /// The item, with its file name, path, size and MIME type.
  final MediaItem item;

  /// Platform id of the folder the item is in, or `null` if unknown.
  final String? albumId;

  /// Display name of that folder, e.g. `Camera`.
  final String albumName;

  /// Revision of the item, as in [LibrarySnapshot.revisions].
  final int revision;

  /// Whether [MediaItem.takenAt] was read from the file's metadata (EXIF,
  /// video creation time) rather than being the date the file was added.
  final bool hasMetadataDate;
}
