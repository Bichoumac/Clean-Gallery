import 'package:flutter/widgets.dart';

/// Detects a two-finger pinch over [child] and reports zoom steps.
///
/// Uses raw pointer events instead of a scale gesture recognizer, so it
/// never competes with the scroll view for one-finger drags. Each time the
/// distance between the two fingers grows or shrinks by [threshold], one
/// step is reported and the reference distance is reset.
class PinchToChangeColumns extends StatefulWidget {
  /// Creates the detector.
  const PinchToChangeColumns({
    required this.child,
    required this.onZoomIn,
    required this.onZoomOut,
    this.threshold = 1.3,
    super.key,
  });

  /// Content, usually a scrollable grid.
  final Widget child;

  /// Fingers moved apart: show fewer, larger items.
  final VoidCallback onZoomIn;

  /// Fingers moved together: show more, smaller items.
  final VoidCallback onZoomOut;

  /// Distance ratio that triggers one step.
  final double threshold;

  @override
  State<PinchToChangeColumns> createState() => _PinchToChangeColumnsState();
}

class _PinchToChangeColumnsState extends State<PinchToChangeColumns> {
  final _pointers = <int, Offset>{};
  double? _reference;

  double? _distance() {
    if (_pointers.length != 2) return null;
    final points = _pointers.values.toList();
    return (points[0] - points[1]).distance;
  }

  void _onDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    _reference = _distance();
  }

  void _onMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final reference = _reference;
    final current = _distance();
    if (reference == null || current == null || reference == 0) return;
    final ratio = current / reference;
    if (ratio >= widget.threshold) {
      widget.onZoomIn();
      _reference = current;
    } else if (ratio <= 1 / widget.threshold) {
      widget.onZoomOut();
      _reference = current;
    }
  }

  void _onUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    _reference = _distance();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: widget.child,
    );
  }
}
