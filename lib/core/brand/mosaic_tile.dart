import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:clean_gallery/core/theme/app_transitions.dart';
import 'package:flutter/material.dart';

/// A tile of the mosaics of Albums and Stats: something at the top (an icon or
/// a label), something at the bottom (a title or a number).
class MosaicTile extends StatelessWidget {
  /// Creates a tile. Without [color], it is a card tile with a thin border.
  const MosaicTile({
    required this.top,
    required this.bottom,
    required this.semanticLabel,
    this.color,
    this.onTap,
    this.onLongPress,
    this.minHeight = 118,
    super.key,
  });

  /// Space between tiles.
  static const gap = 10.0;

  /// Upper part of the tile.
  final Widget top;

  /// Lower part of the tile.
  final Widget bottom;

  /// What a screen reader says about the tile.
  final String semanticLabel;

  /// Background of the tile; `surfaceContainerLow` by default.
  final Color? color;

  /// Opens what the tile is about.
  final VoidCallback? onTap;

  /// Shows the tile's options.
  final VoidCallback? onLongPress;

  /// Height of the tile, at least; it grows with the text.
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppTheme.cornerRadius);
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: color ?? colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: color == null
              ? BorderSide(color: colors.outlineVariant)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  // The page it opens grows out of the tile.
                  TransitionOrigin.mark(context);
                  onTap!();
                },
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [top, const SizedBox(height: 10), bottom],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two widgets side by side, as high as the taller one, [MosaicTile.gap]
/// apart.
class MosaicRow extends StatelessWidget {
  /// Creates the row.
  const MosaicRow({required this.left, required this.right, super.key});

  /// Widget on the left.
  final Widget left;

  /// Widget on the right.
  final Widget right;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        const SizedBox(width: MosaicTile.gap),
        Expanded(child: right),
      ],
    ),
  );
}
