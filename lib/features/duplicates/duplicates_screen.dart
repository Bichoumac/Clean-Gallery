import 'dart:async';

import 'package:clean_gallery/analysis/image_quality.dart';
import 'package:clean_gallery/core/brand/best_pill.dart';
import 'package:clean_gallery/core/brand/empty_state.dart';
import 'package:clean_gallery/core/media/analysis_progress.dart';
import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_actions.dart';
import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/duplicate_group.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/features/duplicates/duplicate_selection.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Side of a member's thumbnail in a group, in logical pixels.
const _thumbSide = 136.0;

/// Duplicate groups of one folder or tab ([scope]), of three kinds:
/// identical copies, bursts and similar photos. Choice chips at the top
/// show all of them, in one section per kind, or a single kind. Each group
/// shows its items side by side, the one to keep marked "Best" and the
/// others picked for the trash. The user can change the picks, trash a
/// group, mark similar photos "Not duplicates", or clean every group shown
/// at once. See `docs/features/duplicates.md`.
class DuplicatesScreen extends ConsumerStatefulWidget {
  /// Creates the screen for the items of [scope], showing only the groups
  /// of [kind] at first, or every group when it is `null`.
  const DuplicatesScreen({required this.scope, this.kind, super.key});

  /// Filter and folder the duplicates are looked for in.
  final MediaSelection scope;

  /// The kind of groups shown at first, or `null` for all of them.
  final DuplicateKind? kind;

  /// Route location of the screen showing only the groups of [kind], to
  /// push with the scope as `extra`.
  static String location(DuplicateKind kind) =>
      '${AppRoutes.duplicates}?kind=${kind.name}';

  @override
  ConsumerState<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends ConsumerState<DuplicatesScreen> {
  /// The kind of groups shown, or `null` for all of them.
  late DuplicateKind? _kind = widget.kind;

  /// Whether the groups with the most items come first, rather than the
  /// newest.
  bool _largestFirst = false;

  MediaSelection get scope => widget.scope;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = ref.watch(duplicateGroupsProvider(scope));
    final scan = ref.watch(duplicateScanProvider);
    final scanning = scan.running;
    final changes = ref.watch(duplicateSelectionProvider(scope));
    final all = groups.value ?? const <DuplicateGroup>[];
    final counts = {
      for (final kind in DuplicateKind.values)
        kind: all.where((g) => g.kind == kind).length,
    };
    final shown = [
      for (final group in all)
        if (_kind == null || group.kind == _kind) group,
    ];
    if (_largestFirst) {
      // Groups of one size stay newest first.
      final order = {for (final (i, g) in shown.indexed) g.id: i};
      shown.sort((a, b) {
        final bySize = b.items.length.compareTo(a.items.length);
        return bySize != 0 ? bySize : order[a.id]!.compareTo(order[b.id]!);
      });
    }
    // An item can be in a certain group and a similar group: count it once.
    final picked = {
      for (final group in shown)
        for (final item in pickedItems(changes, group)) item.id: item,
    }.values.toList();
    final kinds = counts.values.where((n) => n > 0).length;
    // Chips only help when there is more than one kind to choose from, or
    // to go back to all of them.
    final filters = kinds > 1 || (_kind != null && kinds > 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.duplicatesTitle),
        actions: [
          PopupMenuButton<bool>(
            tooltip: l10n.sortTitle,
            icon: const Icon(Icons.sort_rounded),
            initialValue: _largestFirst,
            onSelected: (value) => setState(() => _largestFirst = value),
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: false,
                checked: !_largestFirst,
                child: Text(l10n.sortNewest),
              ),
              CheckedPopupMenuItem(
                value: true,
                checked: _largestFirst,
                child: Text(l10n.sortMostDuplicates),
              ),
            ],
          ),
        ],
        bottom: scanning
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: analysisFraction(scan),
                  minHeight: 2,
                ),
              )
            : null,
      ),
      body: switch (groups) {
        AsyncData() when all.isEmpty => _Empty(scanning: scanning),
        AsyncData() => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (filters) ...[
              _KindChips(
                selected: _kind,
                counts: counts,
                onSelected: (kind) => setState(() => _kind = kind),
              ),
              const SizedBox(height: 8),
            ],
            if (shown.isEmpty)
              _Empty(scanning: scanning)
            else
              for (final kind in DuplicateKind.values)
                if (shown.where((g) => g.kind == kind).toList()
                    case final section when section.isNotEmpty) ...[
                  // A single kind is named by its chip.
                  if (_kind == null) _SectionTitle(_kindTitle(l10n, kind)),
                  for (final group in section)
                    _GroupCard(
                      key: ValueKey(group.id),
                      scope: scope,
                      group: group,
                    ),
                ],
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: picked.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: () => _cleanAll(context, ref, picked),
                  icon: const Icon(Icons.cleaning_services_rounded),
                  label: Text(l10n.duplicatesCleanAll),
                ),
              ),
            ),
    );
  }

  /// Confirms with a summary, then moves every picked item shown to the
  /// trash.
  Future<void> _cleanAll(
    BuildContext context,
    WidgetRef ref,
    List<MediaItem> picked,
  ) async {
    final l10n = AppLocalizations.of(context);
    final bytes = picked.fold<int>(0, (sum, item) => sum + item.sizeBytes);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.duplicatesCleanTitle(picked.length, formatBytes(context, bytes)),
        ),
        content: Text(l10n.duplicatesCleanBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.duplicatesMove),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && context.mounted) {
      await trashWithUndo(context, ref, picked);
    }
  }
}

/// Title of a section of groups.
/// Name of the section and chip of [kind] groups.
String _kindTitle(AppLocalizations l10n, DuplicateKind kind) => switch (kind) {
  DuplicateKind.exact => l10n.duplicatesKindExact,
  DuplicateKind.burst => l10n.duplicatesBursts,
  DuplicateKind.similar => l10n.duplicatesSimilar,
};

/// "All" and one choice chip per kind of group that has any, with its
/// number of groups. Wraps onto several lines with large text.
class _KindChips extends StatelessWidget {
  const _KindChips({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final DuplicateKind? selected;
  final Map<DuplicateKind, int> counts;
  final ValueChanged<DuplicateKind?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = counts.values.fold(0, (sum, n) => sum + n);
    ChoiceChip chip(DuplicateKind? kind, String label, int count) => ChoiceChip(
      label: Text('$label · $count'),
      selected: selected == kind,
      showCheckmark: false,
      onSelected: (_) => onSelected(kind),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(null, l10n.duplicatesFilterAll, total),
        for (final kind in DuplicateKind.values)
          // The chosen kind keeps its chip once its last group is cleaned.
          if (counts[kind]! > 0 || kind == selected)
            chip(kind, _kindTitle(l10n, kind), counts[kind]!),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}

/// One group: its items side by side and a button to trash the picked ones;
/// similar photos also get "Not duplicates".
class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.scope, required this.group, super.key});

  final MediaSelection scope;
  final DuplicateGroup group;

  /// Opens [item] full screen, swiping through the group.
  void _open(BuildContext context, MediaItem item) {
    // The viewer lists the group like any selection: newest first, then by
    // id (see MediaIndexRepository), so find the item's index in that order.
    final order = [...group.items]
      ..sort((a, b) {
        final byDate = b.takenAt.compareTo(a.takenAt);
        return byDate != 0
            ? byDate
            : (int.tryParse(b.id) ?? 0).compareTo(int.tryParse(a.id) ?? 0);
      });
    unawaited(
      context.push(
        AppRoutes.viewer,
        extra: ViewerArgs(
          selection: MediaSelection(ids: [for (final i in group.items) i.id]),
          initialIndex: order.indexWhere((i) => i.id == item.id),
        ),
      ),
    );
  }

  /// Never groups these photos again; the group disappears.
  Future<void> _notDuplicates(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context).duplicatesIgnored;
    await ref.read(duplicateScanProvider.notifier).ignore(group);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final changes = ref.watch(duplicateSelectionProvider(scope));
    final picked = pickedIn(changes, group);
    final toTrash = pickedItems(changes, group);
    final pixels = (_thumbSide * MediaQuery.devicePixelRatioOf(context))
        .round();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in group.items)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Member(
                        item: item,
                        pixelSize: pixels,
                        isBest: item.id == group.best.id,
                        picked: picked.contains(item.id),
                        onOpen: () => _open(context, item),
                        onToggle: () => ref
                            .read(duplicateSelectionProvider(scope).notifier)
                            .toggle(group, item.id),
                      ),
                    ),
                ],
              ),
            ),
            // Side by side when they fit, stacked otherwise (large text).
            OverflowBar(
              alignment: group.kind == DuplicateKind.similar
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              children: [
                if (group.kind == DuplicateKind.similar)
                  TextButton(
                    onPressed: () => _notDuplicates(context, ref),
                    child: Text(l10n.duplicatesNotDuplicates),
                  ),
                TextButton.icon(
                  onPressed: toTrash.isEmpty
                      ? null
                      : () => trashWithUndo(context, ref, toTrash),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(l10n.duplicatesTrashGroup(toTrash.length)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One item of a group: thumbnail, "Best" badge or pick button, then its
/// resolution, "Blurry" when it is, size and date.
class _Member extends StatelessWidget {
  const _Member({
    required this.item,
    required this.pixelSize,
    required this.isBest,
    required this.picked,
    required this.onOpen,
    required this.onToggle,
  });

  final MediaItem item;
  final int pixelSize;
  final bool isBest;
  final bool picked;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final details = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return SizedBox(
      width: _thumbSide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: _thumbSide,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MediaThumbnail(
                    item: item,
                    pixelSize: pixelSize,
                    onTap: onOpen,
                  ),
                  // Picked items are dimmed, so what stays is obvious.
                  if (picked)
                    IgnorePointer(
                      child: ColoredBox(
                        color: colors.scrim.withValues(alpha: 0.35),
                      ),
                    ),
                  if (isBest)
                    const PositionedDirectional(
                      top: 8,
                      start: 8,
                      // Taps go through to the photo.
                      child: IgnorePointer(child: BestPill()),
                    ),
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: IconButton(
                      tooltip: picked
                          ? l10n.duplicatesUnselect
                          : l10n.duplicatesSelect,
                      onPressed: onToggle,
                      icon: Icon(
                        picked
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: picked ? colors.primary : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('${item.width} × ${item.height}', style: details),
          if (item.sharpness case final sharpness?
              when isBlurry(sharpness: sharpness, contrast: item.contrast))
            Text(
              l10n.duplicatesBlurry,
              style: details?.copyWith(color: colors.error),
            ),
          Text(formatBytes(context, item.sizeBytes), style: details),
          Text(
            formatMediaDate(context, item.takenAt),
            style: details,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Where each copy is tells them apart; shown in full, since the
          // end of the path (folder, file name) matters most.
          if (mediaPath(item) case final path?) ...[
            const SizedBox(height: 4),
            Text(path, style: details),
          ],
        ],
      ),
    );
  }
}

/// Nothing to clean, or still looking.
class _Empty extends StatelessWidget {
  const _Empty({required this.scanning});

  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: EmptyState(
        padding: const EdgeInsets.all(32),
        title: scanning ? l10n.duplicatesScanning : l10n.duplicatesEmpty,
        body: scanning ? null : l10n.duplicatesEmptyHelp,
        bodyWidget: scanning
            ? const AnalysisProgressText(textAlign: TextAlign.center)
            : null,
      ),
    );
  }
}
