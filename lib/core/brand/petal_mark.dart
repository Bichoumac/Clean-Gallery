import 'package:clean_gallery/core/theme/app_motion.dart';
import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Number of petals of the rosace.
const petalCount = 8;

/// Index of the lit petal, at 45° (top right). Petals are numbered from the
/// top, clockwise.
const litPetal = 1;

/// Number of lit petals of the Stats gauge: the share of the used space that
/// could be freed, out of eight.
///
/// At least 1 as soon as anything can be freed, 0 when nothing can. The trash
/// is not part of the used space, so the share can go past all of it: the
/// gauge is then full.
int gaugePetals({required int reclaimable, required int used}) {
  if (reclaimable <= 0) return 0;
  if (used <= 0) return petalCount;
  return (reclaimable / used * petalCount).round().clamp(1, petalCount);
}

/// The outline of one petal, pointing up, in a 100 × 100 box. See
/// `docs/design.md#logo`.
Path _petalPath() => Path()
  ..moveTo(50, 45)
  ..cubicTo(46, 38, 40, 28, 40, 19)
  ..arcToPoint(const Offset(60, 19), radius: const Radius.circular(10))
  ..cubicTo(60, 28, 54, 38, 50, 45)
  ..close();

/// Paints the rosace with one color per petal, and optionally one scale per
/// petal for the animations. A scale of 0 hides the petal.
class _RosacePainter extends CustomPainter {
  _RosacePainter({required this.colors, this.scales});

  final List<Color> colors;
  final List<double>? scales;

  static final Path _petal = _petalPath();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint()..isAntiAlias = true;
    for (var i = 0; i < colors.length; i++) {
      final scale = scales?[i] ?? 1;
      if (scale <= 0) continue;
      canvas
        ..save()
        ..translate(50, 50)
        ..rotate(i * 3.141592653589793 / 4)
        ..scale(scale)
        ..translate(-50, -50)
        ..drawPath(_petal, paint..color = colors[i])
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_RosacePainter old) =>
      !_same(old.colors, colors) || !_same(old.scales, scales);

  static bool _same<T>(List<T>? a, List<T>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The rosace of Clean Gallery: eight petals, one color each.
///
/// The mark is decoration: it is hidden from screen readers. Screens say what
/// it means in words.
class PetalMark extends StatelessWidget {
  /// A rosace with [colors], one per petal, from the top, clockwise.
  const PetalMark({required this.size, required this.colors, super.key})
    : assert(colors.length == petalCount, 'One color per petal');

  /// A rosace in [unlit], with the 45° petal in [lit]: the mark of the app.
  factory PetalMark.kept({
    required double size,
    required Color unlit,
    required Color lit,
    Key? key,
  }) => PetalMark(
    size: size,
    colors: List.generate(petalCount, (i) => i == litPetal ? lit : unlit),
    key: key,
  );

  /// Width and height of the rosace.
  final double size;

  /// Color of each petal.
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _RosacePainter(colors: colors),
    ),
  );
}

/// The mark of the empty states: unlit petals in the surface tones of the
/// theme, the 45° petal in the accent.
class EmptyMark extends StatelessWidget {
  /// Creates the mark.
  const EmptyMark({this.size = 140, super.key});

  /// Width and height of the rosace.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PetalMark.kept(
      size: size,
      unlit: colors.brightness == Brightness.dark
          ? colors.surfaceContainerHighest
          : colors.surfaceContainerHigh,
      lit: colors.primaryContainer,
    );
  }
}

/// A single petal at 45°, as in the *Best* pill.
class SinglePetal extends StatelessWidget {
  /// Creates the petal in [color].
  const SinglePetal({required this.size, required this.color, super.key});

  /// Width and height of the box the petal is centered in.
  final double size;

  /// Color of the petal.
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: ClipRect(
        // The petal fills the top right quarter of the rosace: this box shows
        // only that quarter, enlarged.
        child: OverflowBox(
          alignment: Alignment.topRight,
          maxWidth: size * 2,
          maxHeight: size * 2,
          child: CustomPaint(
            size: Size.square(size * 2),
            painter: _RosacePainter(
              colors: List.generate(
                petalCount,
                (i) => i == litPetal ? color : const Color(0x00000000),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Appearance of a rosace: petals grow one after the other, clockwise, the
/// lit one last, in `spring` motion. Plays once when first built.
class BloomingMark extends StatefulWidget {
  /// Creates the animation of a rosace with [colors].
  const BloomingMark({required this.size, required this.colors, super.key})
    : assert(colors.length == petalCount, 'One color per petal');

  /// Width and height of the rosace.
  final double size;

  /// Color of each petal.
  final List<Color> colors;

  @override
  State<BloomingMark> createState() => _BloomingMarkState();
}

class _BloomingMarkState extends State<BloomingMark>
    with SingleTickerProviderStateMixin {
  static const _petal = Duration(milliseconds: 400);
  static const _gap = Duration(milliseconds: 45);
  static final Duration _total = _petal + _gap * (petalCount - 1);
  static final Curve _curve = SpringCurve(AppMotion.spring, duration: _petal);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scale of petal [index] at the time [t] of the animation, in ms.
  double _scale(int index, double t) {
    // The petal after the lit one comes first, the lit one last.
    final order = (index - litPetal - 1) % petalCount;
    final start = order * _gap.inMilliseconds;
    final local = (t - start) / _petal.inMilliseconds;
    return _curve.transform(local.clamp(0, 1));
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * _total.inMilliseconds;
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _RosacePainter(
            colors: widget.colors,
            scales: [for (var i = 0; i < petalCount; i++) _scale(i, t)],
          ),
        );
      },
    ),
  );
}

/// The Stats gauge: [lit] petals in ink from the top, clockwise, the others
/// in the tone on sun. Petals fill one by one when the value changes.
class PetalGauge extends StatelessWidget {
  /// Creates the gauge. [lit] goes from 0 to [petalCount].
  const PetalGauge({required this.lit, this.size = 124, super.key});

  /// Number of lit petals.
  final int lit;

  /// Width and height of the rosace.
  final double size;

  static const _perPetal = Duration(milliseconds: 90);

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: lit.toDouble()),
        // A constant speed would need the previous value; the full gauge
        // takes as long as the longest change.
        duration: AppMotion.of(context, _perPetal * petalCount),
        builder: (context, value, _) => CustomPaint(
          size: Size.square(size),
          painter: _RosacePainter(
            colors: [
              for (var i = 0; i < petalCount; i++)
                Color.lerp(
                  AppColors.petalOnSun,
                  AppColors.ink,
                  (value - i).clamp(0.0, 1.0),
                )!,
            ],
          ),
        ),
      ),
    );
  }
}
