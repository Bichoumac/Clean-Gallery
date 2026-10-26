import 'dart:async';

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
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/timeline.dart';
import 'package:clean_gallery/features/library/fast_scroller.dart';
import 'package:clean_gallery/features/library/pinch_to_change_columns.dart';
import 'package:clean_gallery/features/library/sort_filter_sheet.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                _EmptyState(title: emptyTitle),
            ],
          ),
          AsyncData(:final value) => _Timeline(
            header: header,
            banner: banner,
            selection: shown,
            items: value,
            columns: columns,
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
  });

  final Widget header;
  final Widget? banner;
  final MediaSelection selection;
  final List<MediaItem> items;
  final int columns;

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

  /// Layout of the grid, computed once per list, column count, order, text
  /// size and width; also used to find the item under a finger.
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

  void _toggle(MediaItem item) {
    final picked = {..._picked.value};
    if (!picked.remove(item.id)) picked.add(item.id);
    _setPicked(picked);
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

  /// Index in the items of the thumbnail under [local], a position in the
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
    _dragAdds = !_picked.value.contains(widget.items[index].id);
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

  /// Selects (or deselects) every item between the drag anchor and [index].
  void _selectRangeTo(int index) {
    final anchor = _dragAnchor;
    if (anchor == null) return;
    final low = anchor < index ? anchor : index;
    final high = anchor < index ? index : anchor;
    final range = {for (var i = low; i <= high; i++) widget.items[i].id};
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

  /// Recomputes rows, extents and offsets when what they depend on changed.
  void _updateLayout({
    required List<MediaItem> items,
    required int columns,
    required bool chronological,
    required double headerExtent,
    required double width,
  }) {
    final key = (
      identityHashCode(items),
      items.length,
      columns,
      chronological,
      headerExtent,
      width,
    );
    if (key == _layoutKey) return;
    _layoutKey = key;
    final grouping = groupingForColumns(columns);
    // Date headers only make sense when the list is in date order.
    _rows = chronological
        ? buildRows(groupByDate(items, grouping), columns)
        : buildFlatRows(items.length, columns);
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
    _updateLayout(
      items: items,
      columns: columns,
      chronological: selection.sort.isChronological,
      headerExtent: sectionHeaderExtent(context),
      width: screen.width,
    );
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
      final item = items[index];
      return switch (selection.sort.field) {
        MediaSortField.date => formatMonth(context, item.takenAt),
        MediaSortField.size => formatBytes(context, item.sizeBytes),
        MediaSortField.duration => formatDuration(item.duration),
        MediaSortField.name => switch (item.fileName) {
          final name? when name.isNotEmpty => name[0].toUpperCase(),
          _ => null,
        },
      };
    }

    Widget thumbnail(int index) {
      final item = items[index];
      // Only this cell rebuilds when the selection changes.
      return ValueListenableBuilder<Set<String>>(
        valueListenable: _picked,
        builder: (context, picked, _) {
          final selecting = picked.isNotEmpty;
          return _Selectable(
            selected: selecting ? picked.contains(item.id) : null,
            child: MediaThumbnail(
              item: item,
              pixelSize: pixelSize,
              hero: !selecting,
              onTap: selecting
                  ? () => _toggle(item)
                  : () => context.push(
                      AppRoutes.viewer,
                      extra: ViewerArgs(
                        selection: selection,
                        initialIndex: index,
                      ),
                    ),
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
  });

  final MediaSelection base;
  final String title;
  final bool showBackButton;

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
        padding: EdgeInsets.fromLTRB(showBackButton ? 8 : 20, 24, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (showBackButton) const BackButton(),
                Expanded(
                  child: Text(
                    title,
                    style: showBackButton
                        ? theme.textTheme.headlineMedium
                        : theme.textTheme.displaySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
            if (customized)
              Padding(
                padding: EdgeInsets.only(top: 8, left: showBackButton ? 12 : 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (dates != null)
                      InputChip(
                        avatar: const Icon(Icons.date_range_rounded, size: 18),
                        label: Text(
                          dateFilterLabel(context, dates, DateTime.now()),
                        ),
                        onPressed: () => showSortFilterSheet(context, base),
                        onDeleted: () => notifier.setDates(null),
                      ),
                    if (shown.sort != MediaSort.newest)
                      InputChip(
                        avatar: const Icon(Icons.sort_rounded, size: 18),
                        label: Text(sortLabel(context, shown.sort)),
                        onPressed: () => showSortFilterSheet(context, base),
                        onDeleted: () => notifier.setSort(MediaSort.newest),
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
  const _EmptyState({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => _Message(
    icon: Icons.photo_library_outlined,
    title: title,
    body: AppLocalizations.of(context).libraryEmptyBody,
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
