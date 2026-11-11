import 'dart:async';

import 'package:clean_gallery/core/brand/glass.dart';
import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/widgets/steady_slider.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/features/viewer/video_gestures.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// A video page of the viewer, with Clean Gallery's own controls.
///
/// The player is created when the page is built and plays only while it is
/// the current page. Until the first frame is ready, the thumbnail is shown.
class VideoPage extends ConsumerStatefulWidget {
  /// Creates the page for [item].
  const VideoPage({
    required this.item,
    required this.isCurrent,
    required this.controlsVisible,
    required this.onTap,
    this.bottomInset = 0,
    super.key,
  });

  /// Room left at the bottom for the viewer's action bar, above which the
  /// progress bar sits.
  final double bottomInset;

  /// Video to play.
  final MediaItem item;

  /// Whether this page is the one on screen; others stay paused.
  final bool isCurrent;

  /// Whether the controls are shown (toggled with the viewer's top bar).
  final bool controlsVisible;

  /// Tap on the video: toggles the controls.
  final VoidCallback onTap;

  @override
  ConsumerState<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<VideoPage> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final uri = await ref.read(mediaSourceProvider).videoUri(widget.item);
      if (uri == null) throw StateError('No URI for ${widget.item.id}');
      final controller = VideoPlayerController.contentUri(uri);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      if (widget.isCurrent) await controller.play();
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller == null) return;
    if (oldWidget.isCurrent && !widget.isCurrent) {
      unawaited(controller.pause());
    } else if (!oldWidget.isCurrent && widget.isCurrent) {
      unawaited(controller.play());
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final source = ref.watch(mediaSourceProvider);

    return VideoGestures(
      label: mediaLabel(context, widget.item),
      controller: controller,
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Hero(
              tag: mediaHeroTag(widget.item),
              createRectTween: mediaHeroRectTween(widget.item),
              flightShuttleBuilder: mediaHeroShuttle,
              curve: mediaHeroCurve,
              child: controller != null
                  ? AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    )
                  : Image(
                      image: source.thumbnail(widget.item, size: 512),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
            ),
          ),
          if (_failed)
            Center(
              child: Text(
                AppLocalizations.of(context).viewerLoadError,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          if (controller != null)
            IgnorePointer(
              ignoring: !widget.controlsVisible,
              child: AnimatedOpacity(
                opacity: widget.controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: VideoControls(
                  controller: controller,
                  bottomInset: widget.bottomInset,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Play/pause button in the middle, progress bar and toggles at the bottom.
class VideoControls extends StatefulWidget {
  /// Creates the controls of [controller].
  const VideoControls({
    required this.controller,
    this.bottomInset = 0,
    super.key,
  });

  /// Player the controls drive.
  final VideoPlayerController controller;

  /// Room left below the progress bar, for the viewer's action bar.
  final double bottomInset;

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

/// Space between the slider and the viewer's action bar, so dragging the
/// slider never touches a button.
const _gapAboveActions = 16.0;

class _VideoControlsState extends State<VideoControls> {
  /// Slider position while the user drags it, in milliseconds. The video
  /// only seeks when the finger is lifted, so dragging stays smooth.
  double? _dragMs;

  VideoPlayerController get controller => widget.controller;

  Future<void> _togglePlay(VideoPlayerValue value) async {
    if (value.isCompleted) {
      await controller.seekTo(Duration.zero);
      await controller.play();
    } else if (value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _rotate(BuildContext context) {
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    return SystemChrome.setPreferredOrientations(
      portrait
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final duration = value.duration;
        final position = value.position > duration ? duration : value.position;
        final maxMs = duration.inMilliseconds.clamp(1, 1 << 31).toDouble();
        final sliderMs = (_dragMs ?? position.inMilliseconds.toDouble()).clamp(
          0.0,
          maxMs,
        );
        final (icon, label) = value.isCompleted
            ? (Icons.replay_rounded, l10n.videoReplay)
            : value.isPlaying
            ? (Icons.pause_rounded, l10n.videoPause)
            : (Icons.play_arrow_rounded, l10n.videoPlay);

        return Stack(
          children: [
            Center(
              child: GlassIconButton(
                tooltip: label,
                icon: icon,
                size: 72,
                iconSize: 36,
                onPressed: () => _togglePlay(value),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                // Above the viewer's action bar, which sits above the system
                // navigation bar: the three heights add up. (A SafeArea
                // minimum took the larger of them, and the slider ended up
                // under the action bar, hard to drag.)
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16 + MediaQuery.viewPaddingOf(context).left,
                    0,
                    8 + MediaQuery.viewPaddingOf(context).right,
                    MediaQuery.viewPaddingOf(context).bottom +
                        widget.bottomInset +
                        _gapAboveActions,
                  ),
                  // Fixed height: the Slider otherwise takes all the height
                  // it is given, which put the bar in the middle of the
                  // screen.
                  child: SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        Text(
                          formatDuration(
                            Duration(milliseconds: sliderMs.round()),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        Expanded(
                          // White: no accent over a video.
                          child: SliderTheme(
                            data: const SliderThemeData(
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white30,
                              thumbColor: Colors.white,
                              overlayColor: Colors.white12,
                            ),
                            child: SteadySlider(
                              value: sliderMs,
                              max: maxMs,
                              onChangeStart: (ms) =>
                                  setState(() => _dragMs = ms),
                              onChanged: (ms) => setState(() => _dragMs = ms),
                              onChangeEnd: (ms) async {
                                await controller.seekTo(
                                  Duration(milliseconds: ms.round()),
                                );
                                if (mounted) setState(() => _dragMs = null);
                              },
                            ),
                          ),
                        ),
                        Text(
                          formatDuration(duration),
                          style: const TextStyle(color: Colors.white),
                        ),
                        IconButton(
                          tooltip: value.volume == 0
                              ? l10n.videoUnmute
                              : l10n.videoMute,
                          color: Colors.white,
                          onPressed: () =>
                              controller.setVolume(value.volume == 0 ? 1 : 0),
                          icon: Icon(
                            value.volume == 0
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.videoRotate,
                          color: Colors.white,
                          onPressed: () => _rotate(context),
                          icon: const Icon(Icons.screen_rotation_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
