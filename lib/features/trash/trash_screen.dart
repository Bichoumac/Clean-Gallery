import 'dart:async';

import 'package:clean_gallery/core/brand/empty_state.dart';
import 'package:clean_gallery/core/media/media_actions.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/media/selection_bar.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/compact_nav_bar.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/trashed_item.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app trash: items with the days left before deletion; select them to
/// restore or delete for good, or empty the whole trash.
class TrashScreen extends ConsumerStatefulWidget {
  /// Creates the trash screen.
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  final _selected = <String>{};

  /// Kept to release selection mode after the page is gone, when `ref` can
  /// no longer be used.
  late final SelectionMode _selectionMode = ref.read(
    selectionModeProvider.notifier,
  );

  void _toggle(String id) {
    setState(
      () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
    );
    _selectionMode.set(active: _selected.isNotEmpty);
  }

  void _clearSelection() {
    setState(_selected.clear);
    _selectionMode.set(active: false);
  }

  @override
  void dispose() {
    // Leaving the page must give the navigation bar back; after the frame,
    // since providers cannot change while the tree is being built.
    if (_selected.isNotEmpty) {
      final mode = _selectionMode;
      unawaited(Future.microtask(() => mode.set(active: false)));
    }
    super.dispose();
  }

  Future<void> _restore(List<TrashedItem> items) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(mediaActionsProvider).restore([
      for (final entry in items) entry.item.id,
    ]);
    _clearSelection();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.restoredSnack(items.length))),
    );
  }

  Future<void> _deleteForever(List<TrashedItem> items) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.trashDeleteConfirmTitle(items.length)),
        content: Text(l10n.trashDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    final done = await ref.read(mediaActionsProvider).deleteForever([
      for (final entry in items) entry.item,
    ]);
    if (done) {
      _clearSelection();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l10n.trashDeleteDeclined)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = ref.watch(trashItemsProvider).value ?? const <TrashedItem>[];
    final retention = ref
        .watch(appSettingsControllerProvider)
        .trashRetentionDays;
    final now = DateTime.now();
    final selected = [
      for (final entry in items)
        if (_selected.contains(entry.item.id)) entry,
    ];

    return PopScope(
      canPop: _selected.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: Stack(
        children: [
          // A grid of photos is neutral; the empty page keeps the warm surface.
          Positioned.fill(
            child: ColoredBox(
              color: items.isEmpty
                  ? theme.colorScheme.surface
                  : theme.colorScheme.surfaceContainerLowest,
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 24, 12, 8),
                    child: Row(
                      children: [
                        const BackButton(),
                        Expanded(
                          child: Text(
                            l10n.trashTitle,
                            style: theme.textTheme.headlineLarge,
                          ),
                        ),
                        if (items.isNotEmpty)
                          TextButton(
                            onPressed: () => _deleteForever(items),
                            child: Text(l10n.trashEmptyAll),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    l10n.trashInfo(retention),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              if (items.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyTrash(l10n: l10n, days: retention),
                )
              else
                SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    return _TrashTile(
                      entry: entry,
                      daysLeft: entry.daysLeft(now),
                      selected: _selected.contains(entry.item.id),
                      onTap: () => _toggle(entry.item.id),
                    );
                  },
                ),
              SliverToBoxAdapter(
                child: SizedBox(height: CompactNavBar.contentInset(context)),
              ),
            ],
          ),
          if (_selected.isNotEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: SelectionBar(
                count: selected.length,
                onClose: _clearSelection,
                actions: [
                  SelectionAction(
                    icon: Icons.restore_rounded,
                    label: l10n.actionRestore,
                    onPressed: () => unawaited(_restore(selected)),
                  ),
                  SelectionAction(
                    icon: Icons.delete_forever_rounded,
                    label: l10n.actionDeleteForever,
                    onPressed: () => unawaited(_deleteForever(selected)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Thumbnail with the days left before deletion and a selection mark.
class _TrashTile extends StatelessWidget {
  const _TrashTile({
    required this.entry,
    required this.daysLeft,
    required this.selected,
    required this.onTap,
  });

  final TrashedItem entry;
  final int daysLeft;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.all(selected ? 10 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(selected ? 16 : 0),
              child: MediaThumbnail(
                item: entry.item,
                hero: false,
                onTap: onTap,
              ),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    l10n.trashDaysLeft(daysLeft),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (selected)
            Positioned(
              top: 4,
              left: 4,
              child: IgnorePointer(
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash({required this.l10n, required this.days});

  final AppLocalizations l10n;

  /// How long items stay in the trash, from the settings.
  final int days;

  @override
  Widget build(BuildContext context) =>
      EmptyState(title: l10n.trashEmptyTitle, body: l10n.trashEmptyBody(days));
}
