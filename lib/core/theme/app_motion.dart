import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Motion tokens of `docs/design.md`.
///
/// Animations are quick, follow the finger and can be interrupted. Every one
/// of them drops to an instant change when the system asks for reduced
/// motion: read durations through [of] and check [reduced] before a spring.
abstract final class AppMotion {
  /// Fades of small elements, selection.
  static const quick = Duration(milliseconds: 150);

  /// Curve of [quick] and [standard].
  static const Curve curve = Curves.easeOutCubic;

  /// Tab pill, bars showing and hiding.
  static const standard = Duration(milliseconds: 220);

  /// A page opening: sliding in, or growing from the tile that opened it.
  static const page = Duration(milliseconds: 420);

  /// A page closing, a little quicker than [page].
  static const pageBack = Duration(milliseconds: 340);

  /// Curve of pages and tabs: fast start, long soft landing.
  static const Curve pageCurve = Curves.easeInOutCubicEmphasized;

  /// Moving from one tab to another.
  static const tab = Duration(milliseconds: 300);

  /// Grid to viewer: the photo flying from its thumbnail.
  static const viewer = Duration(milliseconds: 380);

  /// Grid to viewer, tiles, sheets.
  static const spring = SpringDescription(mass: 1, stiffness: 380, damping: 30);

  /// Sort card coming back, stamp.
  static const springBouncy = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 24,
  );

  /// Whether the system asks for no animation.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or nothing under reduced motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// A spring from 0 to 1 as a curve, for tweens played over [duration].
/// Unlike a simulation on a bounded controller, it can overshoot.
class SpringCurve extends Curve {
  /// Creates the curve. [duration] is how long the animation using it lasts.
  SpringCurve(
    SpringDescription spring, {
    this.duration = const Duration(milliseconds: 500),
  }) : _simulation = SpringSimulation(spring, 0, 1, 0);

  /// How long the animation using this curve lasts.
  final Duration duration;

  final SpringSimulation _simulation;

  @override
  double transformInternal(double t) =>
      _simulation.x(t * duration.inMilliseconds / 1000);
}
