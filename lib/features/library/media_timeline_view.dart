import 'dart:async';

import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/duplicates_tile.dart';
import 'package:clean_gallery/core/media/media_actions.dart';
import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/media/selection_bar.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/core/router/compact_nav_bar.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/duplicate_group.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/timeline.dart';
import 'package:clean_gallery/features/library/fast_scroller.dart';
import 'package:clean_gallery/features/library/pinch_to_change_columns.dart';
import 'package:clean_gallery/features/library/sort_filter_sheet.dart';
import 'package:clean_gallery/features/search/search_controller.dart';
import 'package:clean_gallery/features/slideshow/slideshow_actions.dart';
import 'package:clean_gallery/features/slideshow/slideshow_builder.dart';
import 'package:clean_gallery/features/user_albums/user_album_actions.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Extra actions of a timeline's [SelectionBar] for the [picked] items, e.g.
/// *Remove from album* on a user album; [clearSelection] leaves selection
/// mode.
typedef SelectionActionsBuilder = List<SelectionAction> Function(
  List<MediaItem> picked,
  VoidCallback clearSelection,
);

/// Gap between thumbnails, in logical pixels.
const _gap = 2.0;

/// A titled timeline of [selection], with date headers and a pinchable grid.
///
/// Used by the Photos and Videos tabs and by album pages. The user can sort
/// it and limit it to a date range; that choice lives in
/// `viewSelectionProvider(selection)`.
class MediaTimelineView extends ConsumerWidget {
  /// Creates the timeline.
  const MediaTimelineView({
    required this.selection,
    required this.title,
    required this.emptyTitle,
    this.showBackButton = false,
    this.subtitle,
    this.summary,
    this.stackDuplicates = true,
    this.showSearch = false,
    this.compact = false,
    this.showDuplicates = true,
    this.emptyBody,
    this.headerActions = const [],
    this.selectionActions,
    this.slideshowTitle,
    this.topContent,
    super.key,
  });

  /// Base media to show, before the user's sort and date filter.
  final MediaSelection selection;

  /// Large title above the grid.
  final String title;

  /// Title of the empty state.
  final String emptyTitle;

  /// Whether to show a back button before the title (album pages).
  final bool showBackButton;

  /// Line under the title, e.g. the rule of a cleanup list.
  final String? subtitle;

  /// Second line under the title, e.g. "42 items · 1.2 GB".
  final String? summary;

  /// Whether consecutive duplicates fold into one thumbnail while the grid
  /// is in date order. Off for cleanup lists, where every item is a
  /// candidate for the trash.
  final bool stackDuplicates;

  /// Whether the title has a search button (tabs).
  final bool showSearch;

  /// A smaller title without top inset, under another bar (search
  /// results).
  final bool compact;

  /// Whether the Duplicates tile can show above the grid. Off for search
  /// results, whose duplicates are not looked for on their own.
  final bool showDuplicates;

  /// Help text of the empty state, instead of the default one.
  final String? emptyBody;

  /// Buttons after the title, before the search and sort buttons, e.g. a
  /// user album's menu.
  final List<Widget> headerActions;

  /// Actions added at the end of the selection bar, see
  /// [SelectionActionsBuilder].
  final SelectionActionsBuilder? selectionActions;

  /// Title of a slideshow of this timeline, or `null` for no *Slideshow*
  /// button in the title (tabs). The slideshow plays what the timeline
  /// shows, its date range included.
  final String? slideshowTitle;

  /// Shown above the grid, under the title, e.g. the memory cards of the
  /// Camera tab.
  final Widget? topContent;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(mediaAccessProvider);
    await ref.read(mediaIndexProvider.notifier).sync();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(mediaAccessProvider).value;
    final header = _TimelineHeader(
      base: selection,
      title: title,
      showBackButton: showBackButton,
      subtitle: subtitle,
      summary: summary,
      showSearch: showSearch,
      compact: compact,
      actions: headerActions,
      slideshowTitle: slideshowTitle,
    );
    if (access == MediaAccess.denied) {
      return _Scaffolding(
        header: header,
        body: [_AccessPrompt(onGranted: () => _refresh(ref))],
      );
    }

    final shown = ref.watch(viewSelectionProvider(selection));
    final items = ref.watch(visibleMediaListProvider(shown));
    final columns = ref.watch(gridColumnsProvider);
    final banner = access == MediaAccess.limited
        ? const _LimitedAccessBanner()
        : null;

    return PinchToChangeColumns(
      onZoomIn: ref.read(gridColumnsProvider.notifier).zoomIn,
      onZoomOut: ref.read(gridColumnsProvider.notifier).zoomOut,
      child: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: switch (items) {
          AsyncData(:final value) when value.isEmpty => _Scaffolding(
            header: header,
            body: [
              ?banner,
              if (shown.dates != null)
                _FilteredEmptyState(base: selection)
              else
                _EmptyState(title: emptyTitle, body: emptyBody),
            ],
          ),
          AsyncData(:final value) => _Timeline(
            header: header,
            banner: banner,
            selection: shown,
            items: value,
            columns: columns,
            stackDuplicates: stackDuplicates,
            showDuplicates: showDuplicates,
            selectionActions: selectionActions,
            topContent: topContent,
            title: title,
          ),
          AsyncError() => _Scaffolding(
            header: header,
            body: [_ErrorState(onRetry: () => _refresh(ref))],
          ),
          _ => _Skeleton(header: header, columns: columns),
        },
      ),
    );
  }
}

/// The loaded grid: title, optional banner, then header and item rows, with
/// a fast-scroll thumb on the right.
///
/// In date order, consecutive items of one duplicate group taken the same
/// day fold into one cell, a stack, that unfolds in place when tapped. Rows
/// are made of cells; a cell covers one item, or every item of a folded
/// stack.
///
/// Every row has a known height (headers a fixed one, item rows a cell), so
/// the list is a [SliverVariedExtentList]: jumping far with the thumb never
/// lays out the rows in between, and thumbnails one screen ahead are
/// prefetched through `cacheExtent`.
class _Timeline extends ConsumerStatefulWidget {
  const _Timeline({
    required this.header,
    required this.banner,
    required this.selection,
    required this.items,
    required this.columns,
    required this.stackDuplicates,
    required this.showDuplicates,
    required this.selectionActions,
    required this.topContent,
    required this.title,
  });

  final Widget header;
  final Widget? banner;
  final MediaSelection selection;
  final List<MediaItem> items;
  final int columns;
  final bool stackDuplicates;
  final bool showDuplicates;
  final SelectionActionsBuilder? selectionActions;
  final Widget? topContent;

  /// Title of the page, proposed for a slideshow of picked items.
  final String title;

  @override
  ConsumerState<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends ConsumerState<_Timeline> {
  final _scroll = ScrollController();
  final GlobalKey _headerKey = GlobalKey();

  /// Ids of the selected items; selection mode while not empty. A notifier,
  /// so a tap rebuilds the visible cells and the bar, not the whole grid.
  final _picked = ValueNotifier<Set<String>>({});

  /// Selection when the current long-press drag started.
  Set<String> _pickedAtDragStart = {};
  int? _dragAnchor;
  bool _dragAdds = true;
  Offset? _dragPosition;
  Timer? _autoScroll;

  /// Keys of the stacks the user unfolded.
  Set<String> _unfolded = const {};

  /// Stack key by item id and cover id by stack key, from the duplicate
  /// groups; recomputed when the groups change.
  Map<String, String> _stackOf = const {};
  Map<String, String> _coverOf = const {};
  List<DuplicateGroup>? _stackGroups;

  /// Layout of the grid, computed once per list, groups, unfolded stacks,
  /// column count, order, text size and width; also used to find the cell
  /// under a finger. Rows index [_cells].
  List<TimelineCell> _cells = const [];
  List<TimelineRow> _rows = const [];
  List<double> _extents = const [];
  List<double> _offsets = const [];
  double _cell = 0;
  Object? _layoutKey;

  late final SelectionMode _selectionMode = ref.read(
    selectionModeProvider.notifier,
  );

  @override
  void didUpdateWidget(_Timeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Items trashed or reloaded: forget selected ids that are gone.
    if (_picked.value.isNotEmpty && oldWidget.items != widget.items) {
      final present = {for (final item in widget.items) item.id};
      _picked.value = _picked.value.intersection(present);
      _syncSelectionMode();
    }
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    _scroll.dispose();
    final wasSelecting = _picked.value.isNotEmpty;
    _picked.dispose();
    if (wasSelecting) {
      // After the frame: providers cannot change while the tree builds.
      final mode = _selectionMode;
      unawaited(Future.microtask(() => mode.set(active: false)));
    }
    super.dispose();
  }

  void _syncSelectionMode() =>
      _selectionMode.set(active: _picked.value.isNotEmpty);

  void _setPicked(Set<String> picked) {
    _picked.value = picked;
    _syncSelectionMode();
  }

  /// Ids of the items under [cell]: one, or every item of a folded stack.
  Iterable<String> _idsOf(TimelineCell cell) => [
    for (var i = cell.start; i < cell.start + cell.length; i++)
      widget.items[i].id,
  ];

  /// Selects the items under [cell], or deselects them if all were.
  void _toggle(TimelineCell cell) {
    final ids = _idsOf(cell);
    final picked = {..._picked.value};
    if (picked.containsAll(ids)) {
      picked.removeAll(ids);
    } else {
      picked.addAll(ids);
    }
    _setPicked(picked);
  }

  /// Folds or unfolds the stack [key].
  void _toggleStack(String key) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _unfolded = _unfolded.contains(key)
          ? ({..._unfolded}..remove(key))
          : {..._unfolded, key};
    });
  }

  /// Stack keys and covers of [groups] ([groupsByItem]: an item in a
  /// certain group and a similar one stacks with its certain group). A
  /// group is keyed by its best pick, which outlives regroupings that
  /// renumber groups.
  void _updateStacks(List<DuplicateGroup> groups) {
    if (identical(groups, _stackGroups)) return;
    _stackGroups = groups;
    final byItem = groupsByItem(groups);
    _stackOf = {
      for (final MapEntry(:key, :value) in byItem.entries) key: value.best.id,
    };
    _coverOf = {
      for (final group in byItem.values) group.best.id: group.best.id,
    };
  }

  void _clearSelection() => _setPicked({});

  /// Index of the row at [listY], a position inside the list of rows.
  int _rowAt(double listY) {
    var low = 0;
    var high = _rows.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_offsets[mid] <= listY) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  /// Height of the page title, banner and chips above the rows.
  double get _headerHeight {
    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.height ?? 0;
  }

  /// Index in [_cells] of the thumbnail under [local], a position in the
  /// scroll view, or `null` over a header or a gap.
  int? _indexAt(Offset local) {
    if (_rows.isEmpty) return null;
    final y = local.dy + _scroll.offset - _headerHeight;
    if (y < 0) return null;
    final row = _rows[_rowAt(y)];
    if (row is! TimelineItems) return null;
    final column = (local.dx / (_cell + _gap)).floor();
    if (column < 0 || column >= row.length) return null;
    return row.start + column;
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final index = _indexAt(details.localPosition);
    if (index == null) return;
    unawaited(HapticFeedback.selectionClick());
    _dragAnchor = index;
    _pickedAtDragStart = {..._picked.value};
    _dragAdds = !_picked.value.containsAll(_idsOf(_cells[index]));
    _dragPosition = details.localPosition;
    _selectRangeTo(index);
  }

  void _onLongPressMove(LongPressMoveUpdateDetails details) {
    _dragPosition = details.localPosition;
    final index = _indexAt(details.localPosition);
    if (index != null) _selectRangeTo(index);
    _autoScroll ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _autoScrollStep(),
    );
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _autoScroll?.cancel();
    _autoScroll = null;
    _dragAnchor = null;
    _dragPosition = null;
  }

  /// Selects (or deselects) every item between the drag anchor and [index],
  /// both cells, folded stacks included.
  void _selectRangeTo(int index) {
    final anchor = _dragAnchor;
    if (anchor == null) return;
    final low = _cells[anchor < index ? anchor : index];
    final high = _cells[anchor < index ? index : anchor];
    final range = {
      for (var i = low.start; i < high.start + high.length; i++)
        widget.items[i].id,
    };
    _setPicked(
      _dragAdds
          ? _pickedAtDragStart.union(range)
          : _pickedAtDragStart.difference(range),
    );
  }

  /// Scrolls while the dragging finger is near the top or bottom edge.
  void _autoScrollStep() {
    final position = _dragPosition;
    if (position == null || !_scroll.hasClients) return;
    final height = (context.findRenderObject()! as RenderBox).size.height;
    const edge = 96.0;
    const maxSpeed = 18.0;
    final double delta;
    if (position.dy < edge) {
      delta = -maxSpeed * (1 - position.dy / edge);
    } else if (position.dy > height - edge) {
      delta = maxSpeed * (1 - (height - position.dy) / edge);
    } else {
      return;
    }
    final target = (_scroll.offset + delta).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.jumpTo(target);
    final index = _indexAt(position);
    if (index != null) _selectRangeTo(index);
  }

  List<MediaItem> _itemsOf(Set<String> ids) => [
    for (final item in widget.items)
      if (ids.contains(item.id)) item,
  ];

  /// Recomputes cells, rows, extents and offsets when what they depend on
  /// changed.
  void _updateLayout({
    required List<MediaItem> items,
    required bool stacked,
    required int columns,
    required bool chronological,
    required double headerExtent,
    required double width,
  }) {
    final key = (
      identityHashCode(items),
      items.length,
      stacked ? identityHashCode(_stackOf) : null,
      stacked ? identityHashCode(_unfolded) : null,
      columns,
      chronological,
      headerExtent,
      width,
    );
    if (key == _layoutKey) return;
    _layoutKey = key;
    final grouping = groupingForColumns(columns);
    _cells = stacked
        ? buildCells(
            items,
            stackOf: _stackOf,
            coverOf: _coverOf,
            unfolded: _unfolded,
          )
        : [
            for (var i = 0; i < items.length; i++)
              TimelineCell(start: i, cover: i),
          ];
    // Date headers only make sense when the list is in date order. A stack
    // never crosses midnight, so its cover's date is its own.
    _rows = chronological
        ? buildRows(
            groupByDate([for (final c in _cells) items[c.cover]], grouping),
            columns,
          )
        : buildFlatRows(_cells.length, columns);
    _cell = (width - _gap * (columns - 1)) / columns;
    _extents = [
      for (final row in _rows)
        if (row is TimelineHeader) headerExtent else _cell + _gap,
    ];
    final offsets = List<double>.filled(_rows.length, 0);
    for (var i = 1; i < _rows.length; i++) {
      offsets[i] = offsets[i - 1] + _extents[i - 1];
    }
    _offsets = offsets;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final columns = widget.columns;
    final items = widget.items;
    final selection = widget.selection;
    final grouping = groupingForColumns(columns);
    final screen = MediaQuery.sizeOf(context);
    final stacked = widget.stackDuplicates && selection.sort.isChronological;
    if (stacked) {
      _updateStacks(
        ref.watch(duplicateGroupsProvider(duplicateScope(selection))).value ??
            const [],
      );
    }
    _updateLayout(
      items: items,
      stacked: stacked,
      columns: columns,
      chronological: selection.sort.isChronological,
      headerExtent: sectionHeaderExtent(context),
      width: screen.width,
    );
    final cells = _cells;
    final rows = _rows;
    final extents = _extents;
    final cell = _cell;
    // Two size buckets keep cache keys stable while pinching.
    final pixelSize = columns <= 3 ? 512 : 256;

    String? labelAt(double scrollOffset) {
      if (rows.isEmpty) return null;
      final index = switch (rows[_rowAt(scrollOffset - _headerHeight)]) {
        TimelineHeader(:final section) => section.start,
        TimelineItems(:final start) => start,
      };
      final item = items[cells[index].cover];
      return switch (selection.sort.field) {
        MediaSortField.date => formatMonth(context, item.takenAt),
        MediaSortField.size => formatBytes(context, item.sizeBytes),
        MediaSortField.duration => formatDuration(item.duration),
        MediaSortField.name => switch (item.fileName) {
          final name? when name.isNotEmpty => name[0].toUpperCase(),
          _ => null,
        },
        MediaSortField.duplicates => null,
      };
    }

    Widget thumbnail(int index) {
      final cell = cells[index];
      final item = items[cell.cover];
      final stack = cell.stack;
      // Only this cell rebuilds when the selection changes.
      return ValueListenableBuilder<Set<String>>(
        valueListenable: _picked,
        builder: (context, picked, _) {
          final selecting = picked.isNotEmpty;
          final Widget image = MediaThumbnail(
            item: item,
            pixelSize: pixelSize,
            hero: !selecting,
            stackSize: cell.folded ? cell.length : null,
            onTap: selecting
                ? () => _toggle(cell)
                : cell.folded
                ? () => _toggleStack(stack!)
                : () => context.push(
                    AppRoutes.viewer,
                    extra: ViewerArgs(
                      selection: selection,
                      initialIndex: cell.cover,
                    ),
                  ),
          );
          return _Selectable(
            selected: selecting ? picked.containsAll(_idsOf(cell)) : null,
            child: stack == null || cell.folded
                ? image
                : _UnfoldedStackMember(
                    onFold: cell.leads && !selecting
                        ? () => _toggleStack(stack)
                        : null,
                    child: image,
                  ),
          );
        },
      );
    }

    final grid = GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMove,
      onLongPressEnd: _onLongPressEnd,
      child: FastScroller(
        controller: _scroll,
        labelAt: labelAt,
        topPadding: MediaQuery.paddingOf(context).top + 8,
        bottomPadding: CompactNavBar.contentInset(context),
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          // Prefetch thumbnails one screen above and below.
          scrollCacheExtent: ScrollCacheExtent.pixels(screen.height),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                key: _headerKey,
                children: [
                  widget.header,
                  ?widget.banner,
                  ?widget.topContent,
                  // Duplicates are looked for by folder, not by place.
                  if (widget.showDuplicates && widget.selection.area == null)
                    DuplicatesTile(selection: widget.selection),
                ],
              ),
            ),
            SliverVariedExtentList.builder(
              itemCount: rows.length,
              itemExtentBuilder: (index, _) =>
                  index < extents.length ? extents[index] : null,
              itemBuilder: (context, index) => switch (rows[index]) {
                TimelineHeader(:final section) => _SectionHeader(
                  label: formatSectionDate(context, section.date, grouping),
                ),
                TimelineItems(:final start, :final length) => Padding(
                  padding: const EdgeInsets.only(bottom: _gap),
                  child: Row(
                    children: [
                      for (var i = 0; i < columns; i++) ...[
                        if (i > 0) const SizedBox(width: _gap),
                        SizedBox(
                          width: cell,
                          height: cell,
                          child: i < length ? thumbnail(start + i) : null,
                        ),
                      ],
                    ],
                  ),
                ),
              },
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: CompactNavBar.contentInset(context)),
            ),
          ],
        ),
      ),
    );

    return ValueListenableBuilder<Set<String>>(
      valueListenable: _picked,
      // The grid itself does not depend on the selection.
      child: grid,
      builder: (context, pickedIds, grid) {
        final selecting = pickedIds.isNotEmpty;
        final picked = selecting ? _itemsOf(pickedIds) : const <MediaItem>[];
        final allFavorite = picked.every((i) => i.isFavorite);
        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _clearSelection();
          },
          child: Stack(
            children: [
              grid!,
              if (selecting)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SelectionBar(
                    count: picked.length,
                    onClose: _clearSelection,
                    // Share, favorite and trash as buttons; the rest in
                    // the More menu.
                    actions: [
                      SelectionAction(
                        icon: Icons.share_rounded,
                        label: l10n.actionShare,
                        onPressed: () =>
                            unawaited(shareWithOptions(context, ref, picked)),
                      ),
                      SelectionAction(
                        icon: allFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: allFavorite
                            ? l10n.actionUnfavorite
                            : l10n.actionFavorite,
                        onPressed: () {
                          // Hearts switch at once; the selection closes.
                          unawaited(toggleFavorite(context, ref, picked));
                          _clearSelection();
                        },
                      ),
                      SelectionAction(
                        icon: Icons.delete_outline_rounded,
                        label: l10n.actionTrash,
                        onPressed: () {
                          unawaited(trashWithUndo(context, ref, picked));
                          _clearSelection();
                        },
                      ),
                      SelectionAction(
                        icon: Icons.library_add_outlined,
                        label: l10n.actionAddToAlbum,
                        onPressed: () {
                          unawaited(addToAlbum(context, ref, picked));
                          _clearSelection();
                        },
                      ),
                      SelectionAction(
                        icon: Icons.slideshow_rounded,
                        label: l10n.actionSlideshow,
                        onPressed: () {
                          // Picked items, in the order of the timeline.
                          final ids = [for (final item in picked) item.id];
                          _clearSelection();
                          unawaited(
                            startSlideshow(
                              context,
                              ref,
                              PickedSlideshow(ids, title: widget.title),
                            ),
                          );
                        },
                      ),
                      SelectionAction(
                        icon: Icons.select_all_rounded,
                        label: l10n.selectionSelectAll,
                        onPressed: () => _setPicked({
                          for (final item in widget.items) item.id,
                        }),
                      ),
                      ...?widget.selectionActions?.call(
                        picked,
                        _clearSelection,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Selection look of a grid cell: shrunk with rounded corners and a lime
/// check when [selected], an empty ring when selectable, nothing when the
/// grid is not selecting ([selected] is `null`).
class _Selectable extends StatelessWidget {
  const _Selectable({required this.selected, required this.child});

  final bool? selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;
    if (selected == null) return child;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.all(selected ? 10 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(selected ? 14 : 0),
              child: child,
            ),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: IgnorePointer(
              child: selected
                  ? CircleAvatar(
                      radius: 11,
                      backgroundColor: colors.primaryContainer,
                      child: Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: colors.onPrimaryContainer,
                      ),
                    )
                  : Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        color: Colors.black26,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A thumbnail of an unfolded stack: a lime line along its bottom ties the
/// stack's items together, and the cover carries a button that folds the
/// stack again ([onFold]).
class _UnfoldedStackMember extends StatelessWidget {
  const _UnfoldedStackMember({required this.onFold, required this.child});

  final VoidCallback? onFold;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final onFold = this.onFold;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 3,
          child: IgnorePointer(child: ColoredBox(color: colors.primary)),
        ),
        if (onFold != null)
          Positioned(
            top: 0,
            right: 0,
            child: Semantics(
              button: true,
              label: AppLocalizations.of(context).timelineFoldStack,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onFold,
                // A 40-pixel target around the small pill.
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: colors.primaryContainer,
                    child: Icon(
                      Icons.unfold_less_rounded,
                      size: 18,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Height of a date section header, growing with the user's text size.
double sectionHeaderExtent(BuildContext context) =>
    30 + MediaQuery.textScalerOf(context).scale(26);

/// Page title with an optional back button and the sort and filter button,
/// followed by removable chips for the active sort and date filter.
class _TimelineHeader extends ConsumerWidget {
  const _TimelineHeader({
    required this.base,
    required this.title,
    required this.showBackButton,
    required this.showSearch,
    required this.compact,
    required this.actions,
    this.subtitle,
    this.summary,
    this.slideshowTitle,
  });

  final MediaSelection base;
  final String? slideshowTitle;
  final String title;
  final bool showBackButton;
  final bool showSearch;
  final bool compact;
  final String? subtitle;
  final String? summary;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final shown = ref.watch(viewSelectionProvider(base));
    final notifier = ref.read(viewSelectionProvider(base).notifier);
    final customized = shown != base;
    final dates = shown.dates;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          showBackButton ? 8 : 20,
          compact ? 8 : 24,
          12,
          compact ? 8 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (showBackButton) const BackButton(),
                Expanded(
                  child: Text(
                    title,
                    style: compact
                        ? theme.textTheme.titleLarge
                        : showBackButton
                        ? theme.textTheme.headlineMedium
                        : theme.textTheme.displaySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (slideshowTitle case final name?)
                  IconButton(
                    tooltip: l10n.actionSlideshow,
                    onPressed: () => unawaited(
                      startSlideshow(
                        context,
                        ref,
                        SelectionSlideshow(shown, title: name),
                      ),
                    ),
                    icon: const Icon(Icons.slideshow_rounded),
                  ),
                ...actions,
                if (showSearch) SearchButton(scope: base, place: title),
                IconButton(
                  tooltip: l10n.sortFilterTooltip,
                  onPressed: () => showSortFilterSheet(context, base),
                  icon: Badge(
                    isLabelVisible: customized,
                    backgroundColor: theme.colorScheme.primary,
                    smallSize: 8,
                    child: const Icon(Icons.filter_list_rounded),
                  ),
                ),
              ],
            ),
            for (final line in [?subtitle, ?summary])
              Padding(
                padding: EdgeInsets.only(left: showBackButton ? 12 : 0),
                child: Text(
                  line,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (customized && (!compact || shown.sort != base.sort))
              Padding(
                padding: EdgeInsets.only(top: 8, left: showBackButton ? 12 : 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // A search shows its dates among its criteria.
                    if (dates != null && !compact)
                      InputChip(
                        avatar: const Icon(Icons.date_range_rounded, size: 18),
                        label: Text(
                          dateFilterLabel(context, dates, DateTime.now()),
                        ),
                        onPressed: () => showSortFilterSheet(context, base),
                        onDeleted: () => notifier.setDates(null),
                      ),
                    if (shown.sort != base.sort)
                      InputChip(
                        avatar: const Icon(Icons.sort_rounded, size: 18),
                        label: Text(sortLabel(context, shown.sort)),
                        onPressed: () => showSortFilterSheet(context, base),
                        onDeleted: () => notifier.setSort(base.sort),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Date header of a section, at the fixed height of [sectionHeaderExtent].
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Semantics(
          header: true,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}

/// Title and content for non-grid states, scrollable for pull-to-refresh.
class _Scaffolding extends StatelessWidget {
  const _Scaffolding({required this.header, required this.body});

  final Widget header;
  final List<Widget> body;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: CompactNavBar.contentInset(context)),
      children: [header, ...body],
    );
  }
}

/// Grey placeholders while the first chunk loads.
class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.header, required this.columns});

  final Widget header;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    return _Scaffolding(
      header: header,
      body: [
        GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: _gap,
          crossAxisSpacing: _gap,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(columns * 6, (_) => ColoredBox(color: color)),
        ),
      ],
    );
  }
}

/// Centered icon, title and help text inside a page.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 0),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(icon, size: 40, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) => _Message(
    icon: Icons.photo_library_outlined,
    title: title,
    body: body ?? AppLocalizations.of(context).libraryEmptyBody,
  );
}

/// Empty result because of the date filter, with a button to clear it.
class _FilteredEmptyState extends ConsumerWidget {
  const _FilteredEmptyState({required this.base});

  final MediaSelection base;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _Message(
      icon: Icons.event_busy_rounded,
      title: l10n.filterEmptyTitle,
      body: l10n.filterEmptyBody,
      action: OutlinedButton(
        onPressed: () =>
            ref.read(viewSelectionProvider(base).notifier).setDates(null),
        child: Text(l10n.filterClear),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Message(
      icon: Icons.error_outline_rounded,
      title: l10n.libraryLoadError,
      body: '',
      action: OutlinedButton(
        onPressed: onRetry,
        child: Text(l10n.libraryRetry),
      ),
    );
  }
}

class _AccessPrompt extends ConsumerWidget {
  const _AccessPrompt({required this.onGranted});

  final VoidCallback onGranted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _Message(
      icon: Icons.lock_open_rounded,
      title: l10n.libraryAccessTitle,
      body: l10n.libraryAccessBody,
      action: FilledButton(
        onPressed: () async {
          final permissions = ref.read(permissionServiceProvider);
          final access = await permissions.requestMediaAccess();
          if (access == MediaAccess.denied) {
            await permissions.openAppSettings();
          }
          onGranted();
        },
        child: Text(l10n.libraryAccessButton),
      ),
    );
  }
}

class _LimitedAccessBanner extends ConsumerWidget {
  const _LimitedAccessBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.libraryLimitedBanner,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: ref.read(permissionServiceProvider).openAppSettings,
                child: Text(l10n.libraryLimitedAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the search in [scope].
class SearchButton extends StatelessWidget {
  /// Creates the button.
  const SearchButton({required this.scope, required this.place, super.key});

  /// The timeline to search in.
  final MediaSelection scope;

  /// Its name, for the search's title.
  final String place;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).searchTooltip,
    onPressed: () => unawaited(
      context.push(
        AppRoutes.search,
        extra: SearchArgs(scope: scope, place: place),
      ),
    ),
    icon: const Icon(Icons.search_rounded),
  );
}
