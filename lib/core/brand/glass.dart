import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// The translucent pill of the floating bars: `surfaceContainer` at 72 % over
/// a 20 px blur, with a thin inner line, so content scrolls visibly underneath.
class GlassPill extends StatelessWidget {
  /// Creates the pill, [height] high, around [child].
  const GlassPill({required this.height, required this.child, super.key});

  /// Height of the pill.
  final double height;

  /// Content of the pill.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(height / 2);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainer.withValues(alpha: 0.72),
            borderRadius: radius,
            border: Border.all(
              color: colors.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: SizedBox(height: height, child: child),
        ),
      ),
    );
  }
}

/// A round button over a photo or a video: white at 22 % over a blur, a thin
/// white line, a white icon. Never the accent: nothing tints the media.
class GlassIconButton extends StatelessWidget {
  /// Creates the button.
  const GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 56,
    this.iconSize = 26,
    super.key,
  });

  /// Icon of the button.
  final IconData icon;

  /// Tooltip and screen reader label.
  final String tooltip;

  /// Runs the action.
  final VoidCallback? onPressed;

  /// Diameter of the button.
  final double size;

  /// Size of the icon.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: IconButton(
            tooltip: tooltip,
            color: Colors.white,
            iconSize: iconSize,
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            icon: Icon(icon),
          ),
        ),
      ),
    );
  }
}
