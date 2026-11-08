import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clean_gallery/core/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Changes the app's theme with a circle growing from the finger.
///
/// Letting Flutter blend two themes rebuilds the whole app on every frame,
/// which stutters on a phone. Instead, [ThemeReveal] takes a picture of the
/// screen, applies the new theme at once under it, then opens a hole in the
/// picture from where the user last touched the screen until the new theme
/// covers it. The app itself is rebuilt once.
///
/// Placed once around the app, in `MaterialApp.builder`.
class ThemeReveal extends StatefulWidget {
  /// Creates the reveal around [child].
  const ThemeReveal({required this.child, super.key});

  /// The app.
  final Widget child;

  /// How long the circle takes to cover the screen.
  static const duration = Duration(milliseconds: 560);

  /// Runs [change], which switches the theme, with the reveal around it.
  /// Without a [ThemeReveal] above [context], or under reduced motion, it
  /// only runs [change].
  static void change(BuildContext context, VoidCallback change) {
    final state = context.findAncestorStateOfType<_ThemeRevealState>();
    if (state == null) {
      change();
    } else {
      state._run(change);
    }
  }

  @override
  State<ThemeReveal> createState() => _ThemeRevealState();
}

class _ThemeRevealState extends State<ThemeReveal>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundary = GlobalKey();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ThemeReveal.duration,
  );

  /// The screen in the old theme, while the circle grows.
  ui.Image? _picture;

  /// Where the user last touched the screen: the circle's center.
  Offset? _touch;

  void _run(VoidCallback change) {
    final boundary = _boundary.currentContext?.findRenderObject();
    if (AppMotion.reduced(context) ||
        boundary is! RenderRepaintBoundary ||
        !boundary.hasSize) {
      change();
      return;
    }
    final picture = boundary.toImageSync(
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    setState(() {
      _picture?.dispose();
      _picture = picture;
    });
    change();
    _controller.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted) return;
      setState(() {
        _picture?.dispose();
        _picture = null;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _picture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picture = _picture;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => _touch = event.localPosition,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(key: _boundary, child: widget.child),
          if (picture != null)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => ClipPath(
                  clipper: _HoleClipper(
                    center: _touch,
                    progress: AppMotion.pageCurve.transform(_controller.value),
                  ),
                  child: child,
                ),
                child: RawImage(image: picture, fit: BoxFit.fill),
              ),
            ),
        ],
      ),
    );
  }
}

/// The whole area minus a circle around [center] that grows with
/// [progress] until it covers every corner.
class _HoleClipper extends CustomClipper<Path> {
  const _HoleClipper({required this.center, required this.progress});

  final Offset? center;
  final double progress;

  @override
  Path getClip(Size size) {
    final center = this.center ?? size.center(Offset.zero);
    final farthest = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((corner) => (corner - center).distance).reduce(math.max);
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: farthest * progress));
  }

  @override
  bool shouldReclip(_HoleClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.center != center;
}
