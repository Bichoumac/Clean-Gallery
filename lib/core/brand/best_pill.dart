import 'package:clean_gallery/core/brand/petal_mark.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The *Best* pill of a duplicate group, with a small petal: the mark of the
/// app stands for the photo worth keeping.
class BestPill extends StatelessWidget {
  /// Creates the pill; [compact] for a thumbnail strip.
  const BestPill({this.compact = false, super.key});

  /// Whether the pill is the small one of the viewer's strip.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final label = Text(
      AppLocalizations.of(context).duplicatesBest,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style:
          (compact ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
              ?.copyWith(
                color: colors.onPrimaryContainer,
                fontSize: compact ? 10 : null,
              ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 8,
          vertical: compact ? 0 : 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SinglePetal(
              size: compact ? 12 : 18,
              color: colors.onPrimaryContainer,
            ),
            SizedBox(width: compact ? 2 : 4),
            Flexible(child: label),
          ],
        ),
      ),
    );
  }
}
