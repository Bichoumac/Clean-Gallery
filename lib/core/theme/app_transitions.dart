import 'dart:ui' show lerpDouble;

import 'package:clean_gallery/core/theme/app_motion.dart';
import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Where the next page opens from: the tile the user just tapped.
///
/// A tile calls [mark] in its `onTap`, just before navigating. The page that
/// opens right after then grows out of the tile instead of sliding in, and
/// shrinks back into it when it closes. A mark nobody uses expires quickly,
/// so a tap that opens no page does not leak into a later one.
abstract final class TransitionOrigin {
  static Rect? _rect;
  static DateTime? _markedAt;

  /// How long a mark waits for a page to open.
  static const _lifetime = Duration(milliseconds: 600);

  /// Marks the widget of [context] as where the page about to open comes
  /// from.
  static void mark(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    _rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    _markedAt = DateTime.now();
  }

  /// The marked rectangle in global coordinates, if it is still fresh. It
  /// can be taken once.
  static Rect? take() {
    final rect = _rect;
    final markedAt = _markedAt;
    _rect = null;
    _markedAt = null;
    if (rect == null || markedAt == null) return null;
    if (DateTime.now().difference(markedAt) > _lifetime) return null;
    return rect;
  }
}

/// Page transition of every Material page in the app ([docs/design.md]).
///
/// - Opening: the page slides in from the right edge, or grows out of the
///   tile marked with [TransitionOrigin]; the page below recedes a little and
///   darkens.
/// - Closing: the same, played backwards.
/// - Android's predictive back gesture: the page follows the finger, then
///   leaves or springs back when the finger lifts.
/// - Reduced motion: pages change at once.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Creates the builder.
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Duration get reverseTransitionDuration => AppMotion.pageBack;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => AppPageTransition(
    route: route,
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    child: child,
  );
}

/// The transition of one page, built by [AppPageTransitionsBuilder].
class AppPageTransition extends StatefulWidget {
  /// Creates the transition of [route].
  const AppPageTransition({
    required this.route,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    super.key,
  });

  /// Page being shown.
  final PageRoute<dynamic> route;

  /// From 0 (closed) to 1 (open).
  final Animation<double> animation;

  /// From 0 to 1 as another page opens above this one.
  final Animation<double> secondaryAnimation;

  /// Content of the page.
  final Widget child;

  /// How much the page below recedes when another one opens above it.
  static const recededScale = 0.94;

  /// How dark the page below gets, as the scrim's opacity.
  static const recededDim = 0.32;

  @override
  State<AppPageTransition> createState() => _AppPageTransitionState();
}

class _AppPageTransitionState extends State<AppPageTransition>
    with WidgetsBindingObserver {
  /// Tile this page grows out of, in the navigator's coordinates.
  Rect? _origin;

  /// Size of the navigator when the page opened.
  Size _area = Size.zero;

  /// Whether the page is on screen with its tickers on: a page under another
  /// one, or in a hidden tab, must not take the back gesture.
  bool _visible = true;

  /// Whether the page may still grow out of a tile: until its opening
  /// animation is seen to start.
  bool _waitingForOpening = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Takes the tile this page grows out of, once its opening starts. When
  /// the page is first built, the route's animation can still be a
  /// placeholder at 1; a page that opens is then seen moving forward.
  void _takeOriginWhenOpening() {
    if (!_waitingForOpening) return;
    final status = widget.animation.status;
    if (status != AnimationStatus.forward) return;
    _waitingForOpening = false;
    _takeOrigin();
  }

  void _takeOrigin() {
    final global = TransitionOrigin.take();
    if (global == null) return;
    final box = widget.route.navigator?.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    _area = box.size;
    _origin = Rect.fromPoints(
      box.globalToLocal(global.topLeft),
      box.globalToLocal(global.bottomRight),
    );
  }

  // Predictive back, as Flutter's own PredictiveBackPageTransitionsBuilder.

  bool get _canTakeGesture =>
      _visible && widget.route.isCurrent && widget.route.popGestureEnabled;

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !_canTakeGesture) return false;
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) => widget
      .route
      .handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);

  @override
  void handleCancelBackGesture() => widget.route.handleCancelBackGesture();

  @override
  void handleCommitBackGesture() => widget.route.handleCommitBackGesture();

  @override
  Widget build(BuildContext context) {
    _visible = TickerMode.valuesOf(context).enabled;
    if (AppMotion.reduced(context)) return widget.child;
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.animation,
        widget.secondaryAnimation,
      ]),
      child: widget.child,
      builder: (context, child) {
        _takeOriginWhenOpening();
        // Under the finger, the page moves with it; otherwise it eases.
        final dragging = widget.route.navigator?.userGestureInProgress ?? false;
        final curve = dragging ? Curves.linear : AppMotion.pageCurve;
        final shown = curve.transform(widget.animation.value);
        final covered = curve.transform(widget.secondaryAnimation.value);
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            color: colors.scrim.withValues(
              alpha: AppPageTransition.recededDim * covered,
            ),
          ),
          child: Transform.scale(
            scale: lerpDouble(1, AppPageTransition.recededScale, covered),
            child: _PageMotion(
              origin: _origin,
              area: _area,
              progress: shown,
              linear: widget.animation.value,
              background: colors.surface,
              child: child!,
            ),
          ),
        );
      },
    );
  }
}

/// The page at [progress], from 0 (closed) to 1 (open).
///
/// Without [origin], the page slides in from the right edge. With one, a
/// card in the tile's shape opens to the full screen while the page fades
/// in inside it. The widgets are the same in both cases and at every
/// value, so the page keeps its state whatever happens.
class _PageMotion extends StatelessWidget {
  const _PageMotion({
    required this.origin,
    required this.area,
    required this.progress,
    required this.linear,
    required this.background,
    required this.child,
  });

  /// Tile the page grows out of, in the navigator's coordinates.
  final Rect? origin;

  /// Size of the navigator.
  final Size area;

  /// Eased progress, for the geometry.
  final double progress;

  /// Raw progress, for the fades.
  final double linear;

  /// Color of the card before the page appears in it.
  final Color background;

  final Widget child;

  static const _cardFade = Interval(0, 0.2);
  static const _contentFade = Interval(0.12, 0.55);

  @override
  Widget build(BuildContext context) {
    final origin = this.origin;
    var transform = Matrix4.identity();
    _CardClipper? clipper;
    var cardAlpha = 0.0;
    var contentOpacity = 1.0;
    if (origin != null && area.width > 0) {
      final rect = Rect.lerp(origin, Offset.zero & area, progress)!;
      final scale = rect.width / area.width;
      final radius = lerpDouble(AppTheme.cornerRadius, 0, progress)!;
      transform = Matrix4.translationValues(rect.left, rect.top, 0)
        ..scaleByDouble(scale, scale, 1, 1);
      clipper = _CardClipper(
        height: scale == 0 ? 0 : rect.height / scale,
        radius: scale == 0 ? 0 : radius / scale,
      );
      cardAlpha = background.a * _cardFade.transform(linear);
      contentOpacity = _contentFade.transform(linear);
    }
    return FractionalTranslation(
      translation: Offset(origin == null ? 1 - progress : 0, 0),
      child: Transform(
        transform: transform,
        child: ClipRRect(
          clipper: clipper,
          // Nothing to clip while sliding.
          clipBehavior: clipper == null ? Clip.none : Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: background.withValues(alpha: cardAlpha)),
              Opacity(opacity: contentOpacity, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// The top [height] of the page, with rounded corners.
class _CardClipper extends CustomClipper<RRect> {
  const _CardClipper({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  RRect getClip(Size size) => RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, size.width, height.clamp(0, size.height)),
    Radius.circular(radius),
  );

  @override
  bool shouldReclip(_CardClipper oldClipper) =>
      oldClipper.height != height || oldClipper.radius != radius;
}
