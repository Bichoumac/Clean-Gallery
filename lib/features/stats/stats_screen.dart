import 'package:clean_gallery/core/router/home_shell.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Stats tab: how much space cleaning could free, by category.
///
/// Values come from the analysis engine (M3 to M5). Until then every value
/// shows "—"; the layout is final. Each category will open its cleanup tool.
class StatsScreen extends StatelessWidget {
  /// Creates the Stats tab.
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return TabPage(
      title: l10n.navStats,
      children: [
        Card(
          color: colors.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
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
                  l10n.statsValueUnknown,
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.statsReclaimablePending,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _CategoryRow(
                icon: Icons.copy_all_rounded,
                label: l10n.statsDuplicates,
                value: l10n.statsValueUnknown,
              ),
              const Divider(indent: 64),
              _CategoryRow(
                icon: Icons.blur_on_rounded,
                label: l10n.statsBlurry,
                value: l10n.statsValueUnknown,
              ),
              const Divider(indent: 64),
              _CategoryRow(
                icon: Icons.screenshot_rounded,
                label: l10n.statsScreenshots,
                value: l10n.statsValueUnknown,
              ),
              const Divider(indent: 64),
              _CategoryRow(
                icon: Icons.movie_rounded,
                label: l10n.statsLargeVideos,
                value: l10n.statsValueUnknown,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One cleanup category: icon, name and reclaimable size.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
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
          Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
