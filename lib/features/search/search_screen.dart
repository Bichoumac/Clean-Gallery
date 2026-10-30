import 'dart:async';

import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/geo.dart';
import 'package:clean_gallery/features/library/media_timeline_view.dart';
import 'package:clean_gallery/features/search/search_controller.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Time without typing before the file name is searched.
const searchTypingDelay = Duration(milliseconds: 300);

/// Search: a file name field and criteria chips (type, favorites, folder,
/// area) above the results, a timeline with its own sort and dates.
///
/// The criteria combine; with none, every photo and video shows.
class SearchScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _name = TextEditingController();
  Timer? _typing;

  SearchCriteria get _criteria => ref.read(searchCriteriaProvider.notifier);

  @override
  void dispose() {
    _typing?.cancel();
    _name.dispose();
    super.dispose();
  }

  void _onNameChanged(String text) {
    // Rebuilds the clear button at once; searches once typing pauses.
    setState(() {});
    _typing?.cancel();
    _typing = Timer(searchTypingDelay, () => _criteria.setName(text));
  }

  void _clearName() {
    _typing?.cancel();
    _name.clear();
    setState(() {});
    _criteria.setName('');
  }

  Future<void> _pickFolder(List<Album> folders, String? current) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scroll) => ListView(
          controller: scroll,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l10n.searchFolderTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final folder in folders)
              ListTile(
                title: Text(folder.name),
                subtitle: Text(l10n.albumItemCount(folder.count)),
                selected: folder.id == current,
                onTap: () => Navigator.of(context).pop(folder.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _criteria.setFolder(picked);
  }

  Future<void> _pickArea(GeoArea? current) async {
    final area = await context.push<GeoArea>(AppRoutes.mapPick, extra: current);
    if (area != null) _criteria.setArea(area);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final criteria = ref.watch(searchCriteriaProvider);
    final folders = ref.watch(albumsProvider).value ?? const <Album>[];
    final folderName = folders
        .where((f) => f.id == criteria.albumId)
        .firstOrNull
        ?.name;
    final shown = ref.watch(viewSelectionProvider(criteria));
    final count = ref.watch(visibleMediaListProvider(shown)).value?.length;

    Widget type(MediaFilter filter, String label) => ChoiceChip(
      label: Text(label),
      selected: criteria.filter == filter,
      // Tapping the chip picked again goes back to every type.
      onSelected: (on) => _criteria.setType(on ? filter : MediaFilter.all),
    );

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  const BackButton(),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _name,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: _onNameChanged,
                      onSubmitted: (text) {
                        _typing?.cancel();
                        _criteria.setName(text);
                      },
                      decoration: InputDecoration(
                        hintText: l10n.searchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _name.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: l10n.searchClear,
                                onPressed: _clearName,
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: colors.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Every criterion in sight, on two lines on a phone.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                type(MediaFilter.photos, l10n.searchPhotos),
                type(MediaFilter.videos, l10n.searchVideos),
                type(MediaFilter.screenshots, l10n.searchScreenshots),
                FilterChip(
                  avatar: const Icon(Icons.favorite_outline_rounded),
                  label: Text(l10n.searchFavorites),
                  selected: criteria.favoritesOnly,
                  onSelected: (on) => _criteria.setFavoritesOnly(only: on),
                ),
                InputChip(
                  avatar: const Icon(Icons.folder_outlined),
                  label: Text(folderName ?? l10n.searchFolder),
                  selected: criteria.albumId != null,
                  showCheckmark: false,
                  onPressed: () =>
                      unawaited(_pickFolder(folders, criteria.albumId)),
                  onDeleted: criteria.albumId == null
                      ? null
                      : () => _criteria.setFolder(null),
                ),
                InputChip(
                  avatar: const Icon(Icons.map_outlined),
                  label: Text(
                    criteria.area == null
                        ? l10n.searchArea
                        : l10n.searchAreaPicked,
                  ),
                  selected: criteria.area != null,
                  showCheckmark: false,
                  onPressed: () => unawaited(_pickArea(criteria.area)),
                  onDeleted: criteria.area == null
                      ? null
                      : () => _criteria.setArea(null),
                ),
              ],
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: MediaTimelineView(
                selection: criteria,
                title: l10n.searchResults,
                summary: count == null ? null : l10n.searchCount(count),
                emptyTitle: l10n.searchEmpty,
                compact: true,
                showDuplicates: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
