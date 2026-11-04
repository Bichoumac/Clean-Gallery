import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A thumbnail that asks again when it fails, as long as it is on screen.
///
/// An [Image] whose load fails stays blank until it is rebuilt from scratch.
/// A request dropped by the native loader (too many waiting, after a fast
/// scroll) is not a broken file: it is asked for again for as long as the
/// widget lives. Other failures are asked for again a few times, as
/// MediaStore can be busy, then [failure] is shown.
class RetryingImage extends StatefulWidget {
  /// Creates the image.
  const RetryingImage({
    required this.image,
    required this.failure,
    this.fit = BoxFit.cover,
    this.expand = false,
    super.key,
  });

  /// What to show.
  final ImageProvider image;

  /// Shown once the image is given up on.
  final Widget failure;

  /// How the image fills its space.
  final BoxFit fit;

  /// Whether the image takes all the space, even before it is there.
  final bool expand;

  @override
  State<RetryingImage> createState() => _RetryingImageState();
}

class _RetryingImageState extends State<RetryingImage> {
  /// Times a failure other than a dropped request is asked for again.
  static const _maxRetries = 3;

  /// Wait before asking again for a dropped request.
  static const _droppedDelay = Duration(milliseconds: 400);

  /// Attempts so far: a new key, as an image that failed does not load again
  /// otherwise.
  int _attempt = 0;
  int _retries = 0;
  Timer? _timer;

  @override
  void didUpdateWidget(RetryingImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _timer?.cancel();
      _timer = null;
      _retries = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _askAgain(Duration delay, {required bool counts}) {
    if (_timer != null) return;
    _timer = Timer(delay, () {
      unawaited(widget.image.evict());
      if (!mounted) return;
      setState(() {
        _timer = null;
        _attempt++;
        if (counts) _retries++;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Image(
    key: ValueKey(_attempt),
    image: widget.image,
    fit: widget.fit,
    width: widget.expand ? double.infinity : null,
    height: widget.expand ? double.infinity : null,
    gaplessPlayback: true,
    errorBuilder: (context, error, stackTrace) {
      if (error is PlatformException && error.code == 'dropped') {
        _askAgain(_droppedDelay, counts: false);
        return const SizedBox.shrink();
      }
      if (_retries < _maxRetries) {
        _askAgain(Duration(seconds: _retries + 1), counts: true);
        return const SizedBox.shrink();
      }
      return widget.failure;
    },
  );
}
