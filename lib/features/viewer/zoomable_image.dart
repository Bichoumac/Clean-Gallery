import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scale reached by a double tap.
const _doubleTapScale = 2.5;

/// A photo filling the screen, with pinch-to-zoom and double-tap zoom.
///
/// Built on Flutter's [InteractiveViewer]. The thumbnail is shown until the
/// full image is decoded, so the Hero flight and swiping never show a blank
/// page.
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
  final _transform = TransformationController();
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  Animation<Matrix4>? _zoomAnimation;
  Offset _doubleTapPosition = Offset.zero;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
    _animation.addListener(() {
      final value = _zoomAnimation?.value;
      if (value != null) _transform.value = value;
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      _zoomed = zoomed;
      widget.onZoomChanged(zoomed);
    }
  }

  void _onDoubleTap() {
    final Matrix4 target;
    if (_zoomed) {
      target = Matrix4.identity();
    } else {
      // Zoom around the tapped point.
      final position = _doubleTapPosition;
      target = Matrix4.diagonal3Values(_doubleTapScale, _doubleTapScale, 1)
        ..setTranslationRaw(
          -position.dx * (_doubleTapScale - 1),
          -position.dy * (_doubleTapScale - 1),
          0,
        );
    }
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
    final thumbnail = Image(
      image: source.thumbnail(item, size: 512),
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transform,
        maxScale: 5,
        child: SizedBox.expand(
          child: Hero(
            tag: mediaHeroTag(item),
            child: Image(
              image: source.fullImage(item),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                  frame == null && !wasSynchronouslyLoaded ? thumbnail : child,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text(
                  AppLocalizations.of(context).viewerLoadError,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
