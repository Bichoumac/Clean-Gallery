import 'dart:async';

import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/media/selection_bar.dart';
import 'package:clean_gallery/core/router/compact_nav_bar.dart';
import 'package:clean_gallery/features/trash/trash_purge.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Scaffold of the five main tabs, with the floating [CompactNavBar].
///
/// Each tab keeps its own navigation stack through [navigationShell]. The
/// content extends under the bar; tabs add [CompactNavBar.contentInset] at
/// the bottom of their scrollable content. The bar is hidden while a tab is
/// selecting items, since the tab then shows its [SelectionBar] there.
///
/// At launch and when the app comes back to the foreground, the shell
/// brings the media index up to date, then looks for new duplicates, and
/// offers to purge the expired trash (at most once a day).
class HomeShell extends ConsumerStatefulWidget {
  /// Creates the shell around the branch navigator provided by go_router.
  const HomeShell({required this.navigationShell, super.key});

  /// Manages the tab branches, in the order of `AppRoutes.tabs`.
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onForeground);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onForeground());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onForeground() {
    if (!mounted) return;
    unawaited(_syncAndScan());
    unawaited(offerExpiredTrashPurge(context, ref));
  }

  /// Syncs the media index, then looks for new exact duplicates.
  Future<void> _syncAndScan() async {
    await ref.read(mediaIndexProvider.notifier).sync();
    if (mounted) await ref.read(duplicateScanProvider.notifier).run();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navigationShell = widget.navigationShell;
    final selecting = ref.watch(selectionModeProvider);
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: selecting
          ? null
          : CompactNavBar(
              selectedIndex: navigationShell.currentIndex,
              onSelected: (index) => navigationShell.goBranch(
                index,
                // Tapping the active tab again returns to its root.
                initialLocation: index == navigationShell.currentIndex,
              ),
              destinations: [
                CompactNavDestination(
                  icon: Icons.photo_camera_outlined,
                  selectedIcon: Icons.photo_camera_rounded,
                  label: l10n.navCamera,
                ),
                CompactNavDestination(
                  icon: Icons.smart_display_outlined,
                  selectedIcon: Icons.smart_display_rounded,
                  label: l10n.navVideos,
                ),
                CompactNavDestination(
                  icon: Icons.collections_bookmark_outlined,
                  selectedIcon: Icons.collections_bookmark_rounded,
                  label: l10n.navAlbums,
                ),
                CompactNavDestination(
                  icon: Icons.donut_large_outlined,
                  selectedIcon: Icons.donut_large_rounded,
                  label: l10n.navStats,
                ),
                CompactNavDestination(
                  icon: Icons.tune_outlined,
                  selectedIcon: Icons.tune_rounded,
                  label: l10n.navSettings,
                ),
              ],
            ),
    );
  }
}

/// Page layout shared by the tabs: a large title, then [children].
class TabPage extends StatelessWidget {
  /// Creates a tab page titled [title].
  const TabPage({
    required this.title,
    required this.children,
    this.showBackButton = false,
    super.key,
  });

  /// Large page title.
  final String title;

  /// Whether a back button precedes the title (pages under a tab).
  final bool showBackButton;

  /// Content below the title.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          CompactNavBar.contentInset(context),
        ),
        children: [
          if (showBackButton)
            Row(
              children: [
                const BackButton(),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ],
            )
          else
            Text(title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}

/// Temporary content for tabs that are built in later milestones.
class PlaceholderTab extends StatelessWidget {
  /// Creates the placeholder for the tab titled [title].
  const PlaceholderTab({required this.title, super.key});

  /// Title of the tab.
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return TabPage(
      title: title,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homePlaceholderTitle,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.homePlaceholderBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
