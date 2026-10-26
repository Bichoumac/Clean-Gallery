import 'dart:async';

import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_actions.dart';
import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/duplicate_group.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/features/duplicates/duplicate_selection.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Side of a member's thumbnail in a group, in logical pixels.
const _thumbSide = 136.0;

/// Duplicate groups of one folder or tab ([scope]): each group shows its
/// items side by side, the one to keep marked "Best" and the others picked
/// for the trash. The user can change the picks, trash a group, or clean
/// every group at once. See `docs/features/duplicates.md`.
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
    final picked = [for (final group in loaded) ...pickedItems(changes, group)];

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
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.duplicatesCertain,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final group in value)
              _GroupCard(key: ValueKey(group.id), scope: scope, group: group),
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

/// One group: its items side by side and a button to trash the picked ones.
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
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: toTrash.isEmpty
                    ? null
                    : () => trashWithUndo(context, ref, toTrash),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(l10n.duplicatesTrashGroup(toTrash.length)),
              ),
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
