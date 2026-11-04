import 'package:clean_gallery/core/brand/mosaic_tile.dart';
import 'package:clean_gallery/core/brand/petal_mark.dart';
import 'package:clean_gallery/core/media/analysis_progress.dart';
import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/core/router/home_shell.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/features/cleanup/cleanup_lists.dart';
import 'package:clean_gallery/features/duplicates/duplicates_screen.dart';
import 'package:clean_gallery/features/stats/storage_summary.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Stats tab: the storage dashboard. How much space the library takes, how
/// much cleaning could free, and that space by category; each category
/// opens its cleanup tool.
///
/// See `docs/features/stats.md`.
class StatsScreen extends ConsumerWidget {
  /// Creates the Stats tab.
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(storageSummaryProvider).value;
    final scanning = ref.watch(duplicateScanProvider.select((s) => s.running));
    final unknown = l10n.statsValueUnknown;

    String size(int? bytes) =>
        bytes == null ? unknown : formatBytes(context, bytes);

    void openDuplicates(DuplicateKind kind) => context.push(
      DuplicatesScreen.location(kind),
      extra: duplicateScope(MediaSelection.all),
    );

    const gap = SizedBox(height: MosaicTile.gap);
    return TabPage(
      title: l10n.navStats,
      children: [
        _HeroCard(summary: summary, scanning: scanning),
        gap,
        MosaicRow(
          left: _CategoryTile(
            label: l10n.statsSimilar,
            value: size(summary?.similar.bytes),
            count: summary?.similar.count,
            onTap: () => openDuplicates(DuplicateKind.similar),
          ),
          right: _CategoryTile(
            label: l10n.statsLargeVideos,
            value: size(summary?.largeVideos.bytes),
            count: summary?.largeVideos.count,
            onTap: () =>
                context.go(CleanupRoutes.location(CleanupList.largeVideos)),
          ),
        ),
        gap,
        MosaicRow(
          left: _CategoryTile(
            label: l10n.statsExact,
            value: size(summary?.exact.bytes),
            count: summary?.exact.count,
            onTap: () => openDuplicates(DuplicateKind.exact),
          ),
          right: _CategoryTile(
            label: l10n.statsBursts,
            value: size(summary?.burst.bytes),
            count: summary?.burst.count,
            onTap: () => openDuplicates(DuplicateKind.burst),
          ),
        ),
        gap,
        const _SortTile(),
        gap,
        MosaicRow(
          left: _CategoryTile(
            label: l10n.statsScreenshots,
            value: size(summary?.screenshots.bytes),
            count: summary?.screenshots.count,
            onTap: () =>
                context.go(CleanupRoutes.location(CleanupList.screenshots)),
          ),
          right: _CategoryTile(
            label: l10n.statsBlurry,
            value: size(summary?.poorQuality.bytes),
            count: summary?.poorQuality.count,
            onTap: () =>
                context.go(CleanupRoutes.location(CleanupList.poorQuality)),
          ),
        ),
        gap,
        _CategoryTile(
          label: l10n.statsTrash,
          value: size(summary?.trash.bytes),
          count: summary?.trash.count,
          onTap: () => context.go(AlbumRoutes.trash),
        ),
      ],
    );
  }
}

/// The sun card: space that cleaning could free, out of the space the library
/// takes, as a number and a gauge in the shape of the logo.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.summary, required this.scanning});

  final StorageSummary? summary;
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final summary = this.summary;
    final ink = colors.onPrimaryContainer;
    final faded = ink.withValues(alpha: 0.75);
    final used = summary?.usedBytes ?? 0;
    final reclaimable = summary?.reclaimableBytes ?? 0;
    final percent = used <= 0
        ? (reclaimable > 0 ? 100 : 0)
        : (reclaimable / used * 100).round().clamp(0, 100);

    return Card(
      color: colors.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    l10n.statsReclaimableTitle,
                    style: theme.textTheme.titleSmall?.copyWith(color: ink),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: l10n.statsGaugeLabel(percent),
                  child: PetalGauge(
                    lit: gaugePetals(reclaimable: reclaimable, used: used),
                  ),
                ),
              ],
            ),
            // Scales down to fit at large text sizes instead of being clipped.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                summary == null
                    ? l10n.statsValueUnknown
                    : formatBytes(context, reclaimable),
                maxLines: 1,
                style: theme.textTheme.displayLarge?.copyWith(color: ink),
              ),
            ),
            if (summary != null) ...[
              const SizedBox(height: 4),
              Text(
                l10n.statsUsed(formatBytes(context, used)),
                style: theme.textTheme.bodySmall?.copyWith(color: faded),
              ),
              Text(
                _breakdown(context, summary),
                style: theme.textTheme.bodySmall?.copyWith(color: faded),
              ),
            ],
            if (scanning) ...[
              const SizedBox(height: 8),
              Text(
                l10n.statsReclaimablePending,
                style: theme.textTheme.bodySmall?.copyWith(color: faded),
              ),
              AnalysisProgressText(
                style: theme.textTheme.bodySmall?.copyWith(color: faded),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `Photos 12 GB  ·  Videos 40 GB`.
String _breakdown(BuildContext context, StorageSummary summary) {
  final l10n = AppLocalizations.of(context);
  final photos = formatBytes(context, summary.totals.photoBytes);
  final videos = formatBytes(context, summary.totals.videoBytes);
  return '${l10n.statsPhotos} $photos  ·  ${l10n.statsVideos} $videos';
}

/// One cleanup category: its name at the top, then the size it could free and
/// its number of items.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.count,
  });

  final String label;
  final String value;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final detail = switch (count) {
      final n? => l10n.statsItems(n),
      null => null,
    };
    return MosaicTile(
      semanticLabel: [label, value, ?detail].join(', '),
      onTap: onTap,
      top: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.headlineMedium,
            ),
          ),
          if (detail != null)
            Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// *Sort mode*, the one wide tile in the inverse color.
class _SortTile extends StatelessWidget {
  const _SortTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return MosaicTile(
      semanticLabel: '${l10n.swipeTitle}, ${l10n.swipeEntryHelp}',
      color: colors.inverseSurface,
      minHeight: 0,
      onTap: () => context.go(SwipeRoutes.sources),
      top: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.swipeTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onInverseSurface,
                  ),
                ),
                Text(
                  l10n.swipeEntryHelp,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onInverseSurface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, color: colors.onInverseSurface),
        ],
      ),
      bottom: const SizedBox.shrink(),
    );
  }
}
