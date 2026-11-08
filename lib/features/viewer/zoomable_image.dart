import 'dart:math' as math;

import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scale reached by a double tap.
const _doubleTapScale = 2.5;

/// Largest zoom.
const _maxScale = 5.0;

/// Zoom from which the full-resolution image replaces the preview.
const _fullResolutionScale = 1.3;

/// Longest side, in pixels, of the preview of [item] shown by the viewer:
/// the photo fitted in the screen, in physical pixels, capped at 2,560 and at
/// the photo's own size.
///
/// A landscape photo on a portrait screen only needs the screen's width:
/// asking for the screen's longest side decoded and copied about four times
/// the pixels, and the photo stayed blurry longer before turning sharp.
int viewerPreviewSide(BuildContext context, MediaItem item) {
  final screen =
      MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context);
  final ratio = item.aspectRatio;
  // Fitted size: bound by the width when the photo is wider than the screen.
  final fitted = ratio >= screen.width / screen.height
      ? Size(screen.width, screen.width / ratio)
      : Size(screen.height * ratio, screen.height);
  final own = math.max(item.width, item.height);
  return [fitted.longestSide.round(), 2560, if (own > 0) own].reduce(math.min);
}

/// A photo filling the screen, with pinch-to-zoom, panning and double-tap
/// zoom, inside the viewer's page view.
///
/// Shows a screen-sized preview right away, with the grid thumbnail as a
/// placeholder, and loads the full-resolution image only once zoomed in.
///
/// Gestures: at fit scale, one finger belongs to the page view (swipe to
/// the next photo) and two fingers zoom. Once zoomed, one finger pans; the
/// viewer then locks page swiping. See [_ZoomGestureRecognizer].
class ZoomableImage extends ConsumerStatefulWidget {
  /// Creates the page for [item].
  const ZoomableImage({
    required this.item,
    required this.onTap,
    required this.onZoomChanged,
    super.key,
  });

  /// Photo to show.
  final MediaItem item;

  /// Single tap: toggles the viewer controls.
  final VoidCallback onTap;

  /// Called with `true` when the photo is zoomed in, `false` when back to
  /// fit. The viewer disables page swiping while zoomed.
  final ValueChanged<bool> onZoomChanged;

  @override
  ConsumerState<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends ConsumerState<ZoomableImage>
    with SingleTickerProviderStateMixin {
  /// Current transformation: a uniform scale and a translation.
  final ValueNotifier<Matrix4> _transform = ValueNotifier(Matrix4.identity());
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  Animation<Matrix4>? _zoomAnimation;

  Size _viewport = Size.zero;
  Matrix4 _gestureStart = Matrix4.identity();
  Offset _gestureFocal = Offset.zero;
  Offset _doubleTapPosition = Offset.zero;
  bool _zoomed = false;
  bool _showFullResolution = false;

  double get _scale => _transform.value.getMaxScaleOnAxis();

  @override
  void initState() {
    super.initState();
    _animation.addListener(() {
      final value = _zoomAnimation?.value;
      if (value != null) _setTransform(value);
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _setTransform(Matrix4 value) {
    _transform.value = value;
    final scale = value.getMaxScaleOnAxis();
    final zoomed = scale > 1.01;
    if (zoomed != _zoomed) {
      _zoomed = zoomed;
      widget.onZoomChanged(zoomed);
    }
    if (!_showFullResolution && scale >= _fullResolutionScale) {
      setState(() => _showFullResolution = true);
    }
  }

  /// Matrix scaling by [scale] so that scene point [scene] lands on [focal],
  /// with the translation clamped so the photo never leaves the screen.
  Matrix4 _matrix(double scale, Offset scene, Offset focal) {
    final width = _viewport.width;
    final height = _viewport.height;
    final tx = (focal.dx - scene.dx * scale).clamp(width * (1 - scale), 0.0);
    final ty = (focal.dy - scene.dy * scale).clamp(height * (1 - scale), 0.0);
    return Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(tx, ty, 0);
  }

  /// Scene point currently displayed at [screen].
  Offset _sceneAt(Matrix4 matrix, Offset screen) {
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    return Offset(
      (screen.dx - translation.x) / scale,
      (screen.dy - translation.y) / scale,
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _animation.stop();
    _gestureStart = _transform.value.clone();
    _gestureFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final startScale = _gestureStart.getMaxScaleOnAxis();
    // Allow a little overshoot below 1 while pinching; it springs back.
    final scale = (startScale * details.scale).clamp(0.8, _maxScale);
    final scene = _sceneAt(_gestureStart, _gestureFocal);
    _setTransform(_matrix(scale, scene, details.localFocalPoint));
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_scale < 1) _animateTo(Matrix4.identity());
  }

  void _onDoubleTap() {
    if (_zoomed) {
      _animateTo(Matrix4.identity());
    } else {
      final scene = _sceneAt(_transform.value, _doubleTapPosition);
      _animateTo(_matrix(_doubleTapScale, scene, _doubleTapPosition));
    }
  }

  void _animateTo(Matrix4 target) {
    _zoomAnimation = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic));
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(mediaSourceProvider);
    final item = widget.item;
    final longestSide = viewerPreviewSide(context, item);
    final placeholder = Image(
      image: source.thumbnail(item, size: 256),
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
    final preview = Image(
      image: source.preview(item, longestSide: longestSide),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          frame == null && !wasSynchronouslyLoaded ? placeholder : child,
      errorBuilder: (context, error, stackTrace) => Center(
        child: Text(
          AppLocalizations.of(context).viewerLoadError,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        return RawGestureDetector(
          gestures: {
            _ZoomGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<_ZoomGestureRecognizer>(
                  () => _ZoomGestureRecognizer(isZoomed: () => _zoomed),
                  (recognizer) => recognizer
                    ..onStart = _onScaleStart
                    ..onUpdate = _onScaleUpdate
                    ..onEnd = _onScaleEnd,
                ),
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  TapGestureRecognizer.new,
                  (recognizer) => recognizer.onTap = widget.onTap,
                ),
            DoubleTapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  DoubleTapGestureRecognizer
                >(
                  DoubleTapGestureRecognizer.new,
                  (recognizer) => recognizer
                    ..onDoubleTapDown = (details) {
                      _doubleTapPosition = details.localPosition;
                    }
                    ..onDoubleTap = _onDoubleTap,
                ),
          },
          child: ClipRect(
            child: ValueListenableBuilder<Matrix4>(
              valueListenable: _transform,
              builder: (context, matrix, child) =>
                  Transform(transform: matrix, child: child),
              child: SizedBox.expand(
                child: Hero(
                  tag: mediaHeroTag(item),
                  createRectTween: mediaHeroRectTween(item),
                  curve: mediaHeroCurve,
                  child: _showFullResolution
                      ? Image(
                          image: source.fullImage(item),
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          // Keep the preview until the full image is ready.
                          frameBuilder:
                              (context, child, frame, wasSynchronouslyLoaded) =>
                                  frame == null && !wasSynchronouslyLoaded
                                  ? preview
                                  : child,
                          errorBuilder: (context, error, stackTrace) => preview,
                        )
                      : preview,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Scale recognizer that leaves one-finger drags to the page view unless
/// the photo is zoomed.
///
/// A plain scale recognizer accepts a one-finger pan and wins the gesture
/// arena against the page view's horizontal drag, which made swiping
/// between photos impossible. This one only accepts with two fingers, or
/// with one finger while zoomed (when the page view is locked anyway).
///
/// It claims the gesture as soon as a second finger lands: waiting for the
/// fingers to move let the page view take a pinch whose first finger slid
/// a little first, and the photo did not zoom.
class _ZoomGestureRecognizer extends ScaleGestureRecognizer {
  _ZoomGestureRecognizer({required this.isZoomed});

  /// Whether the photo is currently zoomed in.
  final bool Function() isZoomed;

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerDownEvent && pointerCount >= 2) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void resolve(GestureDisposition disposition) {
    if (disposition == GestureDisposition.accepted &&
        pointerCount < 2 &&
        !isZoomed()) {
      return;
    }
    super.resolve(disposition);
  }
}
