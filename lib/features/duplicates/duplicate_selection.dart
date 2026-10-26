import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/duplicate_group.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'duplicate_selection.g.dart';

/// Items picked for the trash in the duplicates screen of one scope.
///
/// By default every item but the one to keep is picked; the state only
/// records the groups the user changed, by group id.
@riverpod
class DuplicateSelection extends _$DuplicateSelection {
  @override
  Map<int, Set<String>> build(MediaSelection scope) => const {};

  /// Picks or unpicks the item with [id] in [group].
  void toggle(DuplicateGroup group, String id) {
    final picked = {...pickedIn(state, group)};
    if (!picked.remove(id)) picked.add(id);
    state = {...state, group.id: picked};
  }
}

/// Ids picked for the trash in [group], given the [changes] of a
/// [DuplicateSelection].
Set<String> pickedIn(Map<int, Set<String>> changes, DuplicateGroup group) =>
    changes[group.id] ?? {for (final item in group.extras) item.id};

/// Items picked for the trash in [group].
List<MediaItem> pickedItems(
  Map<int, Set<String>> changes,
  DuplicateGroup group,
) {
  final picked = pickedIn(changes, group);
  return [
    for (final item in group.items)
      if (picked.contains(item.id)) item,
  ];
}
