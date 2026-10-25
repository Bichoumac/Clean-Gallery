import 'package:clean_gallery/domain/media_item.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'trashed_item.freezed.dart';

/// A media item in the app trash: hidden everywhere, still on disk until it
/// is restored or deleted for good.
@freezed
abstract class TrashedItem with _$TrashedItem {
  /// Creates a trash entry.
  const factory TrashedItem({
    /// The item, as it was when trashed.
    required MediaItem item,

    /// When it was moved to the trash.
    required DateTime trashedAt,

    /// When it becomes eligible for permanent deletion.
    required DateTime expiresAt,

    /// Folder it came from, e.g. `Camera`.
    required String originalFolder,
  }) = _TrashedItem;

  const TrashedItem._();

  /// Whole days left before expiry at [now], never negative.
  int daysLeft(DateTime now) {
    final left = expiresAt.difference(now);
    if (left.isNegative) return 0;
    return (left.inMinutes / Duration.minutesPerDay).ceil();
  }

  /// Whether the retention period is over at [now].
  bool isExpired(DateTime now) => !expiresAt.isAfter(now);
}
