import 'package:clean_gallery/domain/media_item.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'album.freezed.dart';

/// What a [MediaSelection] contains.
enum MediaFilter {
  /// Photos and videos.
  all,

  /// Photos only.
  photos,

  /// Photos taken with the device camera (the `DCIM/Camera/` folder), the
  /// first tab. Screenshots, received and downloaded images are left out.
  camera,

  /// Videos only.
  videos,

  /// Items marked as favorites in the system gallery, photos and videos.
  favorites,
}

/// Criterion a media list is sorted by.
enum MediaSortField {
  /// Capture date (the date shown in the timeline headers).
  date,

  /// File name, case-insensitive.
  name,

  /// File size in bytes.
  size,

  /// Video length. Photos count as zero.
  duration,
}

/// Sort order of a media list.
@freezed
abstract class MediaSort with _$MediaSort {
  /// Creates a sort order.
  const factory MediaSort({
    @Default(MediaSortField.date) MediaSortField field,

    /// Largest, newest or last-in-alphabet first.
    @Default(true) bool descending,
  }) = _MediaSort;

  const MediaSort._();

  /// Newest first: the default order of every timeline.
  static const newest = MediaSort();

  /// Whether this order groups items by date, so timeline headers apply.
  bool get isChronological => field == MediaSortField.date;
}

/// Capture-date range: items from [start] (included) to [end] (excluded).
///
/// Either bound can be `null` for an open range. Dates are local time.
@freezed
abstract class DateFilter with _$DateFilter {
  /// Creates a range.
  const factory DateFilter({DateTime? start, DateTime? end}) = _DateFilter;

  const DateFilter._();

  /// Range covering the calendar days [first] to [last], both included.
  factory DateFilter.days(DateTime first, DateTime last) => DateFilter(
    start: DateTime(first.year, first.month, first.day),
    end: DateTime(last.year, last.month, last.day + 1),
  );

  /// Whether [date] falls inside the range.
  bool contains(DateTime date) =>
      (start == null || !date.isBefore(start!)) &&
      (end == null || date.isBefore(end!));
}

/// A set of media to display: a filter, optionally limited to one folder,
/// with a sort order and an optional date range.
///
/// Used as the key of the media list providers, so equal selections share
/// the same loaded list, and the viewer swipes in the grid's order.
@freezed
abstract class MediaSelection with _$MediaSelection {
  /// Creates a selection.
  const factory MediaSelection({
    @Default(MediaFilter.all) MediaFilter filter,

    /// Folder id, or `null` for the whole library.
    String? albumId,

    /// Sort order; newest first by default.
    @Default(MediaSort.newest) MediaSort sort,

    /// Capture-date range, or `null` for all dates.
    DateFilter? dates,
  }) = _MediaSelection;

  /// Every photo, newest first.
  static const photos = MediaSelection(filter: MediaFilter.photos);

  /// Photos of the device camera, newest first (Camera tab).
  static const camera = MediaSelection(filter: MediaFilter.camera);

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

    /// Newest item, shown as the album cover; `null` if not known yet.
    MediaItem? cover,
  }) = _Album;

  const Album._();

  /// Selection of this album's media.
  MediaSelection get selection => MediaSelection(albumId: id);
}
