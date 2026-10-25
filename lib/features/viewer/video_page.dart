import 'dart:async';

import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/media_item.dart';
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
    super.key,
  });

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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Hero(
              tag: mediaHeroTag(widget.item),
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
                child: _VideoControls(controller: controller),
              ),
            ),
        ],
      ),
    );
  }
}

/// Play/pause button in the middle, progress bar and toggles at the bottom.
class _VideoControls extends StatelessWidget {
  const _VideoControls({required this.controller});

  final VideoPlayerController controller;

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
    final colors = Theme.of(context).colorScheme;

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final duration = value.duration;
        final position = value.position > duration ? duration : value.position;
        final (icon, label) = value.isCompleted
            ? (Icons.replay_rounded, l10n.videoReplay)
            : value.isPlaying
            ? (Icons.pause_rounded, l10n.videoPause)
            : (Icons.play_arrow_rounded, l10n.videoPlay);

        return Stack(
          children: [
            Center(
              child: IconButton.filled(
                tooltip: label,
                iconSize: 36,
                style: IconButton.styleFrom(
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  minimumSize: const Size(72, 72),
                ),
                onPressed: () => _togglePlay(value),
                icon: Icon(icon),
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
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                  child: Row(
                    children: [
                      Text(
                        formatDuration(position),
                        style: const TextStyle(color: Colors.white),
                      ),
                      Expanded(
                        child: Slider(
                          value: position.inMilliseconds.toDouble(),
                          max: duration.inMilliseconds
                              .clamp(1, 1 << 31)
                              .toDouble(),
                          onChanged: (ms) => controller.seekTo(
                            Duration(milliseconds: ms.round()),
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
          ],
        );
      },
    );
  }
}
