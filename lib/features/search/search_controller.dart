import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/geo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_controller.g.dart';

/// Where a search looks, and the name of that place for its title.
class SearchArgs {
  /// Creates the arguments.
  const SearchArgs({required this.scope, required this.place});

  /// The timeline searched in, e.g. `MediaSelection.camera` or a folder.
  final MediaSelection scope;

  /// Its name, e.g. "Camera".
  final String place;
}

/// The search's starting selection inside [scope]: no criterion yet, an
/// empty name. The Favorites album becomes "only favorites", so the type
/// can still be picked.
MediaSelection searchStart(MediaSelection scope) => MediaSelection(
  filter: scope.filter == MediaFilter.favorites
      ? MediaFilter.all
      : scope.filter,
  albumId: scope.albumId,
  favoritesOnly: scope.favoritesOnly || scope.filter == MediaFilter.favorites,
  nameContains: '',
);

/// The search criteria inside [scope], as the [MediaSelection] the results
/// show: type (`filter`), folder, favorites, part of the file name and
/// area. Dates and sort are the results' own, set with their sort and
/// filter button.
@riverpod
class SearchCriteria extends _$SearchCriteria {
  /// Keeps the results' view (sort, dates) alive between two criteria.
  ProviderSubscription<MediaSelection>? _view;

  @override
  MediaSelection build(MediaSelection scope) {
    ref.onDispose(() => _view?.close());
    return searchStart(scope);
  }

  /// Only file names containing [text]; empty for any name.
  void setName(String text) => _set(state.copyWith(nameContains: text.trim()));

  /// Only photos, videos or screenshots; [MediaFilter.all] for both kinds.
  void setType(MediaFilter filter) => _set(state.copyWith(filter: filter));

  /// Only the folder [albumId], or every folder when `null`.
  void setFolder(String? albumId) => _set(state.copyWith(albumId: albumId));

  /// Only favorites, or not.
  void setFavoritesOnly({required bool only}) =>
      _set(state.copyWith(favoritesOnly: only));

  /// Only items taken in [area], or anywhere when `null`.
  void setArea(GeoArea? area) => _set(state.copyWith(area: area));

  /// Moves to [next], keeping the sort and dates picked for the results.
  void _set(MediaSelection next) {
    if (next == state) return;
    final shown = ref.read(viewSelectionProvider(state));
    final previous = _view;
    _view = ref.listen(viewSelectionProvider(next), (_, _) {});
    ref.read(viewSelectionProvider(next).notifier).keepFrom(shown);
    previous?.close();
    state = next;
  }
}
