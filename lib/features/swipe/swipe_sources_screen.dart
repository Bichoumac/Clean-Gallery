import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/core/router/home_shell.dart';
import 'package:clean_gallery/features/swipe/swipe_source.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sort mode, first page: what to go through. All photos, blurry photos and
/// old screenshots, then each month and each folder. A source with a
/// session in progress shows how many cards are sorted, and resumes.
///
/// See `docs/features/swipe.md`.
class SwipeSourcesScreen extends ConsumerWidget {
  /// Creates the page.
  const SwipeSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final progress = ref.watch(swipeProgressProvider).value ?? const {};
    final months = ref.watch(swipeMonthsProvider).value ?? const [];
    final folders = ref.watch(albumsProvider).value ?? const [];

    Widget tile(
      SwipeSource source,
      String title, {
      IconData? icon,
      int? count,
    }) {
      final sorted = progress[source.key];
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: icon == null ? null : Icon(icon),
        title: Text(title),
        subtitle: switch ((count, sorted)) {
          (_, final sorted?) => Text(l10n.swipeSourceResume(sorted)),
          (final count?, _) => Text(l10n.statsItems(count)),
          _ => null,
        },
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(SwipeRoutes.location(source, title)),
      );
    }

    Widget section(String title, List<Widget> tiles) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: tiles),
          ),
        ],
      ),
    );

    return TabPage(
      title: l10n.swipeTitle,
      showBackButton: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text(
            l10n.swipeHelp,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        section(l10n.swipeSectionStart, [
          tile(
            const SwipeSource.allPhotos(),
            l10n.swipeSourceAll,
            icon: Icons.photo_library_outlined,
          ),
          tile(
            const SwipeSource.blurry(),
            l10n.statsBlurry,
            icon: Icons.blur_on_rounded,
          ),
          tile(
            const SwipeSource.screenshots(),
            l10n.statsScreenshots,
            icon: Icons.screenshot_rounded,
          ),
        ]),
        if (months.isNotEmpty)
          section(l10n.swipeSectionMonths, [
            for (final month in months)
              tile(
                SwipeSource.month(month.month),
                formatMonth(context, month.month),
                count: month.count,
              ),
          ]),
        if (folders.isNotEmpty)
          section(l10n.swipeSectionFolders, [
            for (final folder in folders)
              tile(
                SwipeSource.folder(folder.id),
                folder.name,
                count: folder.count,
              ),
          ]),
      ],
    );
  }
}
