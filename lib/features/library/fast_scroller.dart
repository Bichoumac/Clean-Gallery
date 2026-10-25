import 'dart:async';

import 'package:flutter/material.dart';

/// Draggable scroll thumb on the right edge of a long list, with a bubble
/// showing where the user is going (a month, a file size…).
///
/// The thumb is hidden until the list scrolls, then fades out after a short
/// pause. Dragging it jumps straight to any position, which pairs with a
/// fixed-extent list so that far jumps never lay out the rows in between.
class FastScroller extends StatefulWidget {
  /// Wraps [child], a scroll view driven by [controller].
  const FastScroller({
    required this.controller,
    required this.child,
    required this.labelAt,
    this.topPadding = 0,
    this.bottomPadding = 0,
    super.key,
  });

  /// Controller of the wrapped scroll view.
  final ScrollController controller;

  /// The scroll view.
  final Widget child;

  /// Text of the bubble for the content at a scroll offset, or `null` to
  /// show no bubble.
  final String? Function(double offset) labelAt;

  /// Space kept free above the track (status bar, page title).
  final double topPadding;

  /// Space kept free below the track (navigation bar).
  final double bottomPadding;

  /// Lists shorter than this many screens get no thumb.
  static const minScreens = 3;

  @override
  State<FastScroller> createState() => _FastScrollerState();
}

class _FastScrollerState extends State<FastScroller> {
  static const _thumbHeight = 48.0;
  static const _touchWidth = 44.0;

  bool _visible = false;
  bool _dragging = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  bool get _canScroll {
    if (!widget.controller.hasClients) return false;
    final position = widget.controller.position;
    return position.hasContentDimensions &&
        position.maxScrollExtent >
            position.viewportDimension * (FastScroller.minScreens - 1);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || !_canScroll) return false;
    if (notification is ScrollUpdateNotification && !_visible) {
      setState(() => _visible = true);
    }
    if (notification is ScrollEndNotification) _scheduleHide();
    return false;
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && !_dragging) setState(() => _visible = false);
    });
  }

  void _jumpTo(double localY, double trackHeight) {
    final position = widget.controller.position;
    final fraction =
        ((localY - _thumbHeight / 2) / (trackHeight - _thumbHeight)).clamp(
          0.0,
          1.0,
        );
    widget.controller.jumpTo(fraction * position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: widget.topPadding,
            bottom: widget.bottomPadding,
            right: 0,
            left: 0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackHeight = constraints.maxHeight;
                return IgnorePointer(
                  ignoring: !_visible && !_dragging,
                  child: AnimatedOpacity(
                    opacity: _visible || _dragging ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedBuilder(
                      animation: widget.controller,
                      builder: (context, _) {
                        if (!_canScroll) return const SizedBox.shrink();
                        final position = widget.controller.position;
                        final fraction =
                            (position.pixels / position.maxScrollExtent).clamp(
                              0.0,
                              1.0,
                            );
                        final top = fraction * (trackHeight - _thumbHeight);
                        final label = _dragging
                            ? widget.labelAt(position.pixels)
                            : null;
                        return Stack(
                          children: [
                            // The thumb stays first: inserting the bubble
                            // before it would rebuild its gesture detector
                            // mid-drag and lose the drag end.
                            Positioned(
                              key: const ValueKey('thumb'),
                              top: top,
                              right: 0,
                              width: _touchWidth,
                              height: _thumbHeight,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragStart: (details) {
                                  _hideTimer?.cancel();
                                  setState(() => _dragging = true);
                                },
                                onVerticalDragUpdate: (details) {
                                  final box =
                                      context.findRenderObject()! as RenderBox;
                                  _jumpTo(
                                    box
                                        .globalToLocal(details.globalPosition)
                                        .dy,
                                    trackHeight,
                                  );
                                },
                                onVerticalDragEnd: (_) {
                                  setState(() => _dragging = false);
                                  _scheduleHide();
                                },
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: _dragging ? 8 : 6,
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: _dragging
                                          ? colors.primaryContainer
                                          : colors.onSurfaceVariant.withValues(
                                              alpha: 0.6,
                                            ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (label != null)
                              Positioned(
                                key: const ValueKey('bubble'),
                                top: top + _thumbHeight / 2 - 22,
                                right: _touchWidth + 4,
                                child: _Bubble(label: label),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill next to the thumb showing the current position.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.inverseSurface,
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onInverseSurface,
          ),
        ),
      ),
    );
  }
}
