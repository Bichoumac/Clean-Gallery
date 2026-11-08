import 'dart:async';

import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/theme/app_motion.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:clean_gallery/platform/platform_bridge.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

/// The gestures of the video player, as in common video apps
/// ([docs/features/viewer.md]):
///
/// - a tap shows or hides the controls;
/// - sliding up or down on the left half sets the brightness of the app's
///   window (given back to the system when the video is left), on the right
///   half the media volume;
/// - a double tap on the right half jumps 10 s forward, on the left half
///   10 s back; double taps in a row add up;
/// - sliding left or right in the top band of the video sets the playback
///   speed. There, a horizontal slide no longer moves to the next item;
///   anywhere else it does.
///
/// Each gesture shows its value in a pill while it lasts.
class VideoGestures extends ConsumerStatefulWidget {
  /// Creates the gestures driving [controller] around [child].
  const VideoGestures({
    required this.controller,
    required this.onTap,
    required this.child,
    super.key,
  });

  /// Player the gestures drive; `null` until the video is ready, when only
  /// the tap works.
  final VideoPlayerController? controller;

  /// Tap: shows or hides the controls.
  final VoidCallback onTap;

  /// The video and its controls.
  final Widget child;

  /// Jump of a double tap.
  static const seekStep = Duration(seconds: 10);

  /// Playback speeds, slowest first.
  static const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  /// Height of the speed band, as a fraction of the video's height.
  static const speedBand = 0.25;

  /// Horizontal distance from one speed to the next, in logical pixels.
  static const speedStep = 40.0;

  /// Vertical distance from 0 to 100 % of brightness or volume, as a
  /// fraction of the video's height.
  static const levelDistance = 0.6;

  @override
  ConsumerState<VideoGestures> createState() => _VideoGesturesState();
}

enum _Feedback { brightness, volume, speed, seekForward, seekBackward }

class _VideoGesturesState extends ConsumerState<VideoGestures> {
  /// Read in [initState]: `ref` cannot be used in [dispose].
  late final PlatformBridge _bridge;

  /// Size of the area, for the halves and the speed band.
  Size _size = Size.zero;

  /// Pill shown, or `null`.
  _Feedback? _shown;

  /// Content of the pill, kept while it fades out.
  _Feedback _content = _Feedback.volume;
  Timer? _hide;

  // Brightness and volume, from 0 to 1, while a slide moves them.
  double _brightness = 0.5;
  double _volume = 0.5;
  bool _brightnessChanged = false;

  /// Level a vertical slide moves, or `null` when no slide runs.
  _Feedback? _sliding;

  /// Whether the slide moved since it started: a level read from the
  /// platform after that would undo the move.
  bool _slid = false;

  int _speed = VideoGestures.speeds.indexOf(1);
  int _speedAtStart = 0;
  double _speedDrag = 0;

  Offset _doubleTapAt = Offset.zero;

  /// Seconds jumped by the double taps in a row.
  int _seekSeconds = 0;

  @override
  void initState() {
    super.initState();
    _bridge = ref.read(platformBridgeProvider);
  }

  @override
  void dispose() {
    _hide?.cancel();
    // The brightness was for this video only.
    if (_brightnessChanged) unawaited(_bridge.setScreenBrightness(null));
    super.dispose();
  }

  void _show(_Feedback feedback) {
    _hide?.cancel();
    setState(() => _shown = _content = feedback);
  }

  void _hideSoon([Duration after = const Duration(milliseconds: 700)]) {
    _hide?.cancel();
    _hide = Timer(after, () {
      if (mounted) {
        setState(() {
          _shown = null;
          _seekSeconds = 0;
        });
      }
    });
  }

  // Brightness and volume.

  void _onLevelStart(DragStartDetails details) {
    final kind = details.localPosition.dx < _size.width / 2
        ? _Feedback.brightness
        : _Feedback.volume;
    _sliding = kind;
    _slid = false;
    // Start from the current level, which may have changed outside the app
    // (volume buttons, the system's brightness).
    unawaited(
      (kind == _Feedback.brightness && !_brightnessChanged
              ? _bridge.screenBrightness()
              : kind == _Feedback.volume
              ? _bridge.mediaVolume()
              : Future.value(_brightness))
          .then((level) {
            if (!mounted || _sliding != kind || _slid) return;
            setState(() {
              if (kind == _Feedback.brightness) {
                _brightness = level;
              } else {
                _volume = level;
              }
            });
          }),
    );
    _show(kind);
  }

  void _onLevelUpdate(DragUpdateDetails details) {
    final kind = _sliding;
    if (kind == null || _size.height == 0) return;
    _slid = true;
    final delta =
        -(details.primaryDelta ?? 0) /
        (_size.height * VideoGestures.levelDistance);
    if (kind == _Feedback.brightness) {
      _brightness = (_brightness + delta).clamp(0.0, 1.0);
      _brightnessChanged = true;
      unawaited(_bridge.setScreenBrightness(_brightness));
    } else {
      _volume = (_volume + delta).clamp(0.0, 1.0);
      unawaited(_bridge.setMediaVolume(_volume));
    }
    _show(kind);
  }

  void _onLevelEnd([DragEndDetails? _]) {
    _sliding = null;
    _hideSoon();
  }

  // Speed.

  bool _inSpeedBand(Offset position) =>
      position.dy < _size.height * VideoGestures.speedBand;

  void _onSpeedStart(DragStartDetails details) {
    _speedAtStart = _speed;
    _speedDrag = 0;
    _show(_Feedback.speed);
  }

  void _onSpeedUpdate(DragUpdateDetails details) {
    _speedDrag += details.primaryDelta ?? 0;
    final speed = (_speedAtStart + (_speedDrag / VideoGestures.speedStep))
        .round()
        .clamp(0, VideoGestures.speeds.length - 1);
    if (speed != _speed) {
      _speed = speed;
      unawaited(
        widget.controller?.setPlaybackSpeed(VideoGestures.speeds[speed]),
      );
    }
    _show(_Feedback.speed);
  }

  void _onSpeedEnd(DragEndDetails details) => _hideSoon();

  // Double tap.

  void _onDoubleTap() {
    final controller = widget.controller;
    if (controller == null) return;
    final forward = _doubleTapAt.dx >= _size.width / 2;
    final kind = forward ? _Feedback.seekForward : _Feedback.seekBackward;
    // Double taps in a row on the same side add up.
    if (_shown != kind) _seekSeconds = 0;
    _seekSeconds += VideoGestures.seekStep.inSeconds;
    final value = controller.value;
    final target = forward
        ? value.position + VideoGestures.seekStep
        : value.position - VideoGestures.seekStep;
    unawaited(
      controller.seekTo(
        target < Duration.zero
            ? Duration.zero
            : target > value.duration
            ? value.duration
            : target,
      ),
    );
    _show(kind);
    _hideSoon(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.controller?.value.isInitialized ?? false;
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  TapGestureRecognizer.new,
                  (recognizer) => recognizer.onTap = widget.onTap,
                ),
            if (ready) ...{
              DoubleTapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    DoubleTapGestureRecognizer
                  >(
                    DoubleTapGestureRecognizer.new,
                    (recognizer) => recognizer
                      ..onDoubleTapDown = (details) {
                        _doubleTapAt = details.localPosition;
                      }
                      ..onDoubleTap = _onDoubleTap,
                  ),
              VerticalDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    VerticalDragGestureRecognizer
                  >(
                    VerticalDragGestureRecognizer.new,
                    (recognizer) => recognizer
                      ..onStart = _onLevelStart
                      ..onUpdate = _onLevelUpdate
                      ..onEnd = _onLevelEnd
                      ..onCancel = _onLevelEnd,
                  ),
              _BandDragRecognizer:
                  GestureRecognizerFactoryWithHandlers<_BandDragRecognizer>(
                    () => _BandDragRecognizer(inBand: _inSpeedBand),
                    (recognizer) => recognizer
                      ..onStart = _onSpeedStart
                      ..onUpdate = _onSpeedUpdate
                      ..onEnd = _onSpeedEnd
                      ..onCancel = _hideSoon,
                  ),
            },
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _shown == null ? 0 : 1,
                  duration: AppMotion.of(context, AppMotion.quick),
                  child: _pill(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pill(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = _content;
    final (icon, label, level) = switch (content) {
      _Feedback.brightness => (
        Icons.brightness_6_rounded,
        l10n.videoBrightnessLevel((_brightness * 100).round()),
        _brightness,
      ),
      _Feedback.volume => (
        _volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        l10n.videoVolumeLevel((_volume * 100).round()),
        _volume,
      ),
      _Feedback.speed => (
        Icons.speed_rounded,
        l10n.videoSpeedLevel(
          NumberFormat.decimalPatternDigits(
                locale: Localizations.localeOf(context).toString(),
                decimalDigits: 2,
              )
              .format(VideoGestures.speeds[_speed])
              .replaceFirst(RegExp(r'[.,]?0+$'), ''),
        ),
        null,
      ),
      _Feedback.seekForward => (
        Icons.fast_forward_rounded,
        l10n.videoSeekForward(_seekSeconds),
        null,
      ),
      _Feedback.seekBackward => (
        Icons.fast_rewind_rounded,
        l10n.videoSeekBackward(_seekSeconds),
        null,
      ),
    };
    final alignment = switch (content) {
      _Feedback.seekForward => const Alignment(0.6, 0),
      _Feedback.seekBackward => const Alignment(-0.6, 0),
      // Clear of the thumb, near the top of the video.
      _ => const Alignment(0, -0.55),
    };
    return Align(
      alignment: alignment,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              if (level != null) ...[
                SizedBox(
                  width: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: level,
                      minHeight: 4,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(label, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A horizontal slide that only starts in a band of the area: there it wins
/// over the viewer's page swipe; elsewhere it does not take part.
class _BandDragRecognizer extends HorizontalDragGestureRecognizer {
  _BandDragRecognizer({required this.inBand});

  final bool Function(Offset localPosition) inBand;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      inBand(event.localPosition) && super.isPointerAllowed(event);
}
