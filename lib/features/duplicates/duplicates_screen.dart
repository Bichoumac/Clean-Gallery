import 'dart:async';

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

/// Duplicate groups of one folder or tab ([scope]), in two sections:
/// certain duplicates (identical copies, bursts) and similar photos. Each
/// group shows its items side by side, the one to keep marked "Best" and
/// the others picked for the trash. The user can change the picks, trash a
/// group, mark similar photos "Not duplicates", or clean every group at
/// once. See `docs/features/duplicates.md`.
class DuplicatesScreen extends ConsumerWidget {
  /// Creates the screen for the items of [scope].
  const DuplicatesScreen({required this.scope, super.key});

  /// Filter and folder the duplicates are looked for in.
  final MediaSelection scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final groups = ref.watch(duplicateGroupsProvider(scope));
    final scanning = ref.watch(duplicateScanProvider.select((s) => s.running));
    final changes = ref.watch(duplicateSelectionProvider(scope));
    final loaded = groups.value ?? const <DuplicateGroup>[];
    // An item can be in a certain group and a similar group: count it once.
    final picked = {
      for (final group in loaded)
        for (final item in pickedItems(changes, group)) item.id: item,
    }.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.duplicatesTitle),
        bottom: scanning
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: switch (groups) {
        AsyncData(value: []) => _Empty(scanning: scanning),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final (title, section) in [
              (
                l10n.duplicatesCertain,
                value.where((g) => g.kind != DuplicateKind.similar),
              ),
              (
                l10n.duplicatesSimilar,
                value.where((g) => g.kind == DuplicateKind.similar),
              ),
            ])
              if (section.isNotEmpty) ...[
                _SectionTitle(title),
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

  /// Confirms with a summary, then moves every picked item to the trash.
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
            // Similar groups are named by their section.
            if (group.kind != DuplicateKind.similar)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  group.kind == DuplicateKind.exact
                      ? l10n.duplicatesKindExact
                      : l10n.duplicatesKindBurst,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
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
/// resolution, size and date.
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
              borderRadius: BorderRadius.circular(12),
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
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      // Taps go through to the photo.
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Text(
                              l10n.duplicatesBest,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_none_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              scanning ? l10n.duplicatesScanning : l10n.duplicatesEmpty,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (!scanning) ...[
              const SizedBox(height: 8),
              Text(
                l10n.duplicatesEmptyHelp,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
