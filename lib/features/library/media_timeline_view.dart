import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
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
    final shown = ref.read(viewSelectionProvider(selection));
    ref
      ..invalidate(mediaAccessProvider)
      ..invalidate(mediaListProvider(shown));
    await ref.read(mediaListProvider(shown).future);
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
    final items = ref.watch(mediaListProvider(shown));
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
class _Timeline extends StatefulWidget {
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
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  final _scroll = ScrollController();
  final GlobalKey _headerKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.columns;
    final items = widget.items;
    final selection = widget.selection;
    final grouping = groupingForColumns(columns);
    // Date headers only make sense when the list is in date order.
    final rows = selection.sort.isChronological
        ? buildRows(groupByDate(items, grouping), columns)
        : buildFlatRows(items.length, columns);
    final screen = MediaQuery.sizeOf(context);
    final cell = (screen.width - _gap * (columns - 1)) / columns;
    final headerExtent = sectionHeaderExtent(context);
    final extents = [
      for (final row in rows)
        if (row is TimelineHeader) headerExtent else cell + _gap,
    ];
    // Top offset of each row inside the list, for the fast-scroll bubble.
    final offsets = List<double>.filled(rows.length, 0);
    for (var i = 1; i < rows.length; i++) {
      offsets[i] = offsets[i - 1] + extents[i - 1];
    }
    // Two size buckets keep cache keys stable while pinching.
    final pixelSize = columns <= 3 ? 512 : 256;

    String? labelAt(double scrollOffset) {
      if (rows.isEmpty) return null;
      final headerBox =
          _headerKey.currentContext?.findRenderObject() as RenderBox?;
      final y = scrollOffset - (headerBox?.size.height ?? 0);
      // Last row starting at or above the top of the screen.
      var low = 0;
      var high = rows.length - 1;
      while (low < high) {
        final mid = (low + high + 1) ~/ 2;
        if (offsets[mid] <= y) {
          low = mid;
        } else {
          high = mid - 1;
        }
      }
      final index = switch (rows[low]) {
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

    return FastScroller(
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
              children: [widget.header, ?widget.banner],
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
                        child: i < length
                            ? MediaThumbnail(
                                item: items[start + i],
                                pixelSize: pixelSize,
                                onTap: () => context.push(
                                  AppRoutes.viewer,
                                  extra: ViewerArgs(
                                    selection: selection,
                                    initialIndex: start + i,
                                  ),
                                ),
                              )
                            : null,
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
