import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'memory.freezed.dart';

/// Kind of an automatic memory. Stored by name in the database.
enum MemoryKind {
  /// Photos taken on today's date, some years ago.
  onThisDay,

  /// Photos taken during this week (Monday to Sunday), some years ago.
  thisWeek,
}

/// An automatic memory: the good photos of one day or week, some years
/// ago, built by the app from the capture dates while it is open.
///
/// Only the period is stored: the photos are read again when the memory is
/// played, so trashed ones are left out. See `docs/features/memories.md`.
@freezed
abstract class Memory with _$Memory {
  /// Creates a memory.
  const factory Memory({
    /// Stable key, e.g. `thisWeek:2025-11-03`: the kind and the first day.
    required String key,

    /// Day or week.
    required MemoryKind kind,

    /// How many years ago, 1 or more.
    required int yearsAgo,

    /// The day or week, as a capture-date range.
    required DateFilter dates,

    /// Number of good photos found when the memory was built.
    required int count,

    /// Photo shown on the card, when known.
    MediaItem? cover,
  }) = _Memory;

  const Memory._();

  /// Photos of this memory: the camera's photos of its period.
  MediaSelection get selection =>
      MediaSelection(filter: MediaFilter.camera, dates: dates);

  /// Key of the memory of [kind] starting on [start].
  static String keyOf(MemoryKind kind, DateTime start) =>
      '${kind.name}:${start.year.toString().padLeft(4, '0')}-'
      '${start.month.toString().padLeft(2, '0')}-'
      '${start.day.toString().padLeft(2, '0')}';
}
