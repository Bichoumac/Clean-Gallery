/// Shared domain enumerations.
///
/// They live in the domain layer so that the analysis engine, the database
/// and the UI all use the same vocabulary. Values are stored by name in the
/// database, so **renaming a value is a schema change** and needs a migration.
library;

/// Whether an asset is a still image or a video.
enum MediaKind {
  /// A still image.
  photo,

  /// A video clip.
  video,
}

/// Where the capture date of an asset was read from, in priority order.
///
/// See `docs/analysis-engine.md` for the resolution rules.
enum DateSource {
  /// EXIF `DateTimeOriginal`, the most reliable source.
  exif,

  /// Parsed from a known file name pattern.
  filename,

  /// The MediaStore file date, used as a last resort.
  file,
}

/// Category of a duplicate group.
enum DuplicateKind {
  /// Byte-identical content (same size and hash).
  exact,

  /// Photos taken in the same burst sequence.
  burst,

  /// Visually similar photos, found by perceptual hashing.
  similar,
}

/// Action taken on a photo during a swipe session.
enum SwipeAction {
  /// Kept in the library.
  keep,

  /// Moved to the app trash.
  trash,

  /// Marked as a favorite.
  favorite,
}
