import 'package:freezed_annotation/freezed_annotation.dart';

part 'album.freezed.dart';

/// What a [MediaSelection] contains.
enum MediaFilter {
  /// Photos and videos.
  all,

  /// Photos only.
  photos,

  /// Videos only.
  videos,

  /// Items marked as favorites in the system gallery, photos and videos.
  favorites,
}

/// A set of media to display: a filter, optionally limited to one folder.
///
/// Used as the key of the media list providers, so equal selections share
/// the same loaded list.
@freezed
abstract class MediaSelection with _$MediaSelection {
  /// Creates a selection.
  const factory MediaSelection({
    @Default(MediaFilter.all) MediaFilter filter,

    /// Folder id, or `null` for the whole library.
    String? albumId,
  }) = _MediaSelection;

  /// Every photo, newest first (Photos tab).
  static const photos = MediaSelection(filter: MediaFilter.photos);

  /// Every video, newest first (Videos tab).
  static const videos = MediaSelection(filter: MediaFilter.videos);

  /// Every photo and video ("All media" album).
  static const all = MediaSelection();

  /// Favorites ("Favorites" album).
  static const favorites = MediaSelection(filter: MediaFilter.favorites);
}

/// A device folder that contains media, as shown in the Albums tab.
@freezed
abstract class Album with _$Album {
  /// Creates an album.
  const factory Album({
    /// Platform identifier of the folder.
    required String id,

    /// Display name, e.g. `Camera`, `Screenshots`, `WhatsApp Images`.
    required String name,

    /// Number of photos and videos in the folder.
    required int count,
  }) = _Album;

  const Album._();

  /// Selection of this album's media.
  MediaSelection get selection => MediaSelection(albumId: id);
}
