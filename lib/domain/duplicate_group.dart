import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'duplicate_group.freezed.dart';

/// Items considered duplicates of each other, as shown in the duplicates
/// screen.
@freezed
abstract class DuplicateGroup with _$DuplicateGroup {
  /// Creates a group.
  const factory DuplicateGroup({
    /// Database id of the group.
    required int id,

    /// Why the items are grouped.
    required DuplicateKind kind,

    /// Members, the suggested one to keep first. Always at least two.
    required List<MediaItem> items,
  }) = _DuplicateGroup;

  const DuplicateGroup._();

  /// The item suggested to keep (the "Best" badge).
  MediaItem get best => items.first;

  /// The other items, suggested for the trash.
  List<MediaItem> get extras => items.sublist(1);
}
