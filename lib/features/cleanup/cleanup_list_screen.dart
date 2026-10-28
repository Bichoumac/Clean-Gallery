import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/features/cleanup/cleanup_lists.dart';
import 'package:clean_gallery/features/library/media_timeline_view.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A cleanup list opened from the Stats tab: old screenshots, large videos
/// or blurry photos, as a timeline with its item count and size under the
/// title.
///
/// Long-press to select, **Select all**, then move to the trash; see
/// `docs/features/cleanup.md`.
class CleanupListScreen extends ConsumerWidget {
  /// Creates the screen of [list].
  const CleanupListScreen({required this.list, super.key});

  /// List to show.
  final CleanupList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsControllerProvider);
    final selection = ref.watch(cleanupSelectionProvider(list));
    final items = ref.watch(visibleMediaListProvider(selection)).value;
    final bytes = items?.fold(0, (sum, item) => sum + item.sizeBytes) ?? 0;

    return MediaTimelineView(
      selection: selection,
      // Every item here is a candidate for the trash: none hides in a stack.
      stackDuplicates: false,
      title: switch (list) {
        CleanupList.screenshots => l10n.cleanupScreenshotsTitle,
        CleanupList.largeVideos => l10n.cleanupLargeVideosTitle,
        CleanupList.poorQuality => l10n.cleanupBlurryTitle,
      },
      subtitle: switch (list) {
        CleanupList.screenshots => l10n.cleanupScreenshotsRule(
          settings.screenshotAgeDays,
        ),
        CleanupList.largeVideos => l10n.cleanupLargeVideosRule(
          settings.largeVideoMegabytes,
        ),
        CleanupList.poorQuality => l10n.cleanupBlurryRule,
      },
      summary: items == null || items.isEmpty
          ? null
          : l10n.cleanupSummary(items.length, formatBytes(context, bytes)),
      emptyTitle: switch (list) {
        CleanupList.screenshots => l10n.cleanupScreenshotsEmpty,
        CleanupList.largeVideos => l10n.cleanupLargeVideosEmpty,
        CleanupList.poorQuality => l10n.cleanupBlurryEmpty,
      },
      showBackButton: true,
    );
  }
}
