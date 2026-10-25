import 'package:clean_gallery/core/router/compact_nav_bar.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Scaffold of the five main tabs, with the floating [CompactNavBar].
///
/// Each tab keeps its own navigation stack through [navigationShell]. The
/// content extends under the bar; tabs add [CompactNavBar.contentInset] at
/// the bottom of their scrollable content.
class HomeShell extends StatelessWidget {
  /// Creates the shell around the branch navigator provided by go_router.
  const HomeShell({required this.navigationShell, super.key});

  /// Manages the tab branches, in the order of `AppRoutes.tabs`.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: CompactNavBar(
        selectedIndex: navigationShell.currentIndex,
        onSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the active tab again returns to its root.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          CompactNavDestination(
            icon: Icons.image_outlined,
            selectedIcon: Icons.image_rounded,
            label: l10n.navPhotos,
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
  const TabPage({required this.title, required this.children, super.key});

  /// Large page title.
  final String title;

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
