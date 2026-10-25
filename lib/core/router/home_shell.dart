import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Scaffold with the bottom navigation bar for the three main tabs.
///
/// Each tab keeps its own navigation stack through [navigationShell].
class HomeShell extends StatelessWidget {
  /// Creates the shell around the branch navigator provided by go_router.
  const HomeShell({required this.navigationShell, super.key});

  /// Manages the three tab branches.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the active tab again returns to its root.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.photo_library_outlined),
            selectedIcon: const Icon(Icons.photo_library),
            label: l10n.navPhotos,
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: l10n.navFolders,
          ),
          NavigationDestination(
            icon: const Icon(Icons.cleaning_services_outlined),
            selectedIcon: const Icon(Icons.cleaning_services),
            label: l10n.navClean,
          ),
        ],
      ),
    );
  }
}

/// Temporary content for tabs that are built in later milestones.
class PlaceholderTab extends StatelessWidget {
  /// Creates the placeholder.
  const PlaceholderTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(l10n.homePlaceholderTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.homePlaceholderBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
