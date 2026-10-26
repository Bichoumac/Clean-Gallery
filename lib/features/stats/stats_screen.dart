import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/core/router/home_shell.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/features/stats/storage_summary.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Stats tab: the storage dashboard. How much space the library takes, how
/// much cleaning could free, and that space by category; each category
/// opens its cleanup tool.
///
/// Blurry photos, screenshots and large videos come with M5; their rows
/// show "—" until then. See `docs/features/stats.md`.
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

    void openDuplicates() => context.push(
      AppRoutes.duplicates,
      extra: duplicateScope(MediaSelection.all),
    );

    return TabPage(
      title: l10n.navStats,
      children: [
        _HeroCard(summary: summary, scanning: scanning),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _CategoryRow(
                icon: Icons.copy_all_rounded,
                label: l10n.statsCertain,
                detail: summary == null
                    ? null
                    : l10n.statsItems(summary.certain.count),
                value: size(summary?.certain.bytes),
                onTap: openDuplicates,
              ),
              const Divider(indent: 64),
              _CategoryRow(
                icon: Icons.burst_mode_rounded,
                label: l10n.statsSimilar,
                detail: summary == null
                    ? null
                    : l10n.statsItems(summary.similar.count),
                value: size(summary?.similar.bytes),
                onTap: openDuplicates,
              ),
              const Divider(indent: 64),
              _CategoryRow(
                icon: Icons.delete_outline_rounded,
                label: l10n.statsTrash,
                detail: summary == null
                    ? null
                    : l10n.statsItems(summary.trash.count),
                value: size(summary?.trash.bytes),
                onTap: () => context.go(AlbumRoutes.trash),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _CategoryRow(
                icon: Icons.blur_on_rounded,
                label: l10n.statsBlurry,
                detail: l10n.statsLater,
                value: unknown,
              ),
              const Divider(indent: 64),
              _CategoryRow(
                icon: Icons.screenshot_rounded,
                label: l10n.statsScreenshots,
                detail: l10n.statsLater,
                value: unknown,
              ),
              const Divider(indent: 64),
              _CategoryRow(
                icon: Icons.movie_rounded,
                label: l10n.statsLargeVideos,
                detail: l10n.statsLater,
                value: unknown,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The lime card: space that cleaning could free, out of the space the
/// library takes, as a number and a bar.
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
    final faded = colors.onPrimaryContainer.withValues(alpha: 0.7);
    final used = summary?.usedBytes ?? 0;
    final reclaimable = summary?.reclaimableBytes ?? 0;
    // The trash is not part of the used space; the bar can still fill up.
    final fraction = used + (summary?.trash.bytes ?? 0) == 0
        ? 0.0
        : (reclaimable / (used + summary!.trash.bytes)).clamp(0.0, 1.0);

    return Card(
      color: colors.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.statsReclaimableTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              summary == null
                  ? l10n.statsValueUnknown
                  : formatBytes(context, reclaimable),
              style: theme.textTheme.displayLarge?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            if (summary != null) ...[
              const SizedBox(height: 4),
              Text(
                l10n.statsUsed(formatBytes(context, used)),
                style: theme.textTheme.bodyMedium?.copyWith(color: faded),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  color: colors.onPrimaryContainer,
                  backgroundColor: colors.onPrimaryContainer.withValues(
                    alpha: 0.15,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _breakdown(context, summary),
                style: theme.textTheme.bodyMedium?.copyWith(color: faded),
              ),
            ],
            if (scanning) ...[
              const SizedBox(height: 8),
              Text(
                l10n.statsReclaimablePending,
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

/// One cleanup category: icon, name, item count and reclaimable size.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: colors.onSurface),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleSmall),
                  if (detail case final detail?)
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onTap == null
                    ? colors.onSurfaceVariant
                    : colors.onSurface,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}
