import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The "Duplicates" virtual folder at the top of a grid: how many items of
/// the displayed folder are suggested for the trash (extra copies, burst
/// shots, similar photos) and the space they take. Opens the
/// duplicates screen for that folder. Hidden when there is none.
///
/// It exists only in the interface: nothing is created on disk.
class DuplicatesTile extends ConsumerWidget {
  /// Creates the tile for the items of [selection] (filter and folder).
  const DuplicatesTile({required this.selection, super.key});

  /// Selection of the grid the tile is shown in.
  final MediaSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = duplicateScope(selection);
    final groups = ref.watch(duplicateGroupsProvider(scope)).value ?? const [];
    if (groups.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // An item can be in a certain group and a similar group: count it once.
    final extras = {
      for (final group in groups)
        for (final item in group.extras) item.id: item,
    }.values.toList();
    final bytes = extras.fold<int>(0, (sum, item) => sum + item.sizeBytes);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.duplicates, extra: scope),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.filter_none_rounded,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.duplicatesTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        l10n.duplicatesTileSummary(
                          extras.length,
                          formatBytes(context, bytes),
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
