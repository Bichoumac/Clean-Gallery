import 'dart:async';

import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:clean_gallery/features/memories/memory_providers.dart';
import 'package:clean_gallery/features/slideshow/slideshow_actions.dart';
import 'package:clean_gallery/features/slideshow/slideshow_builder.dart';
import 'package:clean_gallery/features/viewer/zoomable_image.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:clean_gallery/platform/music_player.dart';
import 'package:clean_gallery/platform/platform_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// Duration of the crossfade between two items.
const slideshowFade = Duration(milliseconds: 900);

/// Duration of the music's fade-out at the end.
const _musicFadeOut = Duration(seconds: 2);

/// How long the controls stay after a tap while playing.
const _controlsTimeout = Duration(seconds: 3);

/// Full-screen slideshow: dark, screen kept on, photos one after another
/// with a crossfade or a slow zoom, videos muted for
/// [SlideshowOptions.maxVideoSeconds] at most, music in a loop.
///
/// A tap shows the controls: close, previous, pause, next, and *Save*
/// unless it is already a saved slideshow. At the end: replay, save or
/// close. See `docs/features/slideshow.md`.
class SlideshowScreen extends ConsumerStatefulWidget {
  /// Creates the player for [source], with [options] when given, the
  /// user's defaults otherwise.
  const SlideshowScreen({required this.source, this.options, super.key});

  /// What to play.
  final SlideshowSource source;

  /// Options chosen just before, or `null` for the defaults.
  final SlideshowOptions? options;

  @override
  ConsumerState<SlideshowScreen> createState() => _SlideshowScreenState();
}

class _SlideshowScreenState extends ConsumerState<SlideshowScreen>
    with SingleTickerProviderStateMixin {
  BuiltSlideshow? _show;
  var _index = 0;
  var _paused = false;
  var _ended = false;
  var _controlsVisible = false;
  int? _savedId;
  Timer? _hideControls;

  /// Runs once per photo; when it completes, the next item comes.
  late final AnimationController _clock = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });

  /// Fade-out of the music at the end, cancelled by a replay.
  Timer? _fade;

  /// Read once: `ref` cannot be used in [dispose].
  late final MusicPlayer _music = ref.read(musicPlayerProvider);
  late final PlatformBridge _bridge = ref.read(platformBridgeProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_bridge.setKeepScreenOn(on: true));
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    unawaited(_load());
  }

  Future<void> _load() async {
    final options =
        widget.options ??
        ref.read(appSettingsControllerProvider).slideshowOptions;
    final show = await ref
        .read(slideshowBuilderProvider)
        .build(widget.source, options);
    if (!mounted) return;
    setState(() {
      _show = show;
      _savedId = show.savedId;
    });
    if (show.items.isEmpty) return;
    _startItem();
    await _startMusic(show.options.music);
  }

  Future<void> _startMusic(SlideshowMusic music) async {
    if (music is NoMusic) return;
    final played = await _music.play(music);
    if (!played && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).slideshowMusicUnavailable),
        ),
      );
    }
  }

  List<MediaItem> get _items => _show?.items ?? const [];

  /// Starts the clock for a photo; a video says itself when it is done.
  void _startItem() {
    _clock.stop();
    final item = _items[_index];
    if (!item.isVideo) {
      _clock
        ..duration = Duration(seconds: _show!.options.photoSeconds)
        ..value = 0;
      if (!_paused) _clock.forward();
    }
    _precacheNext();
  }

  void _precacheNext() {
    if (_index + 1 >= _items.length) return;
    final next = _items[_index + 1];
    if (next.isVideo) return;
    final source = ref.read(mediaSourceProvider);
    unawaited(
      precacheImage(
        source.preview(next, longestSide: viewerPreviewSide(context, next)),
        context,
        onError: (_, _) {},
      ),
    );
  }

  void _next() {
    if (!mounted || _ended) return;
    if (_index + 1 >= _items.length) {
      _end();
      return;
    }
    setState(() => _index++);
    _startItem();
  }

  void _previous() {
    if (_index == 0) {
      _startItem();
      return;
    }
    setState(() {
      _index--;
      _ended = false;
    });
    _startItem();
  }

  void _end() {
    _clock.stop();
    setState(() {
      _ended = true;
      _controlsVisible = false;
    });
    final music = _music;
    const steps = 10;
    var step = 0;
    _fade?.cancel();
    _fade = Timer.periodic(_musicFadeOut ~/ steps, (timer) {
      step++;
      if (step >= steps) {
        timer.cancel();
        unawaited(music.stop());
      } else {
        unawaited(music.setVolume(1 - step / steps));
      }
    });
  }

  Future<void> _replay() async {
    _fade?.cancel();
    setState(() {
      _index = 0;
      _ended = false;
      _paused = false;
    });
    _startItem();
    await _startMusic(_show!.options.music);
  }

  void _togglePause() {
    final music = _music;
    setState(() => _paused = !_paused);
    if (_paused) {
      _clock.stop();
      unawaited(music.pause());
      _hideControls?.cancel();
    } else {
      if (!_items[_index].isVideo) _clock.forward();
      unawaited(music.resume());
      _scheduleHide();
    }
  }

  void _toggleControls() {
    if (_ended) return;
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _scheduleHide() {
    _hideControls?.cancel();
    if (_paused) return;
    _hideControls = Timer(_controlsTimeout, () {
      if (mounted && !_paused) setState(() => _controlsVisible = false);
    });
  }

  Future<void> _save() async {
    final show = _show;
    if (show == null) return;
    final wasPaused = _paused;
    if (!wasPaused) _togglePause();
    final id = await saveSlideshow(
      context,
      ref,
      title: show.title ?? '',
      options: show.options,
      items: show.items,
    );
    if (!mounted) return;
    if (id != null) setState(() => _savedId = id);
    if (!wasPaused && !_ended) _togglePause();
  }

  @override
  void dispose() {
    _hideControls?.cancel();
    _fade?.cancel();
    _clock.dispose();
    unawaited(_music.stop());
    unawaited(_bridge.setKeepScreenOn(on: false));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final show = _show;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: switch (show) {
          null => const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          ),
          BuiltSlideshow(:final items) when items.isEmpty => _Message(
            text: l10n.slideshowEmpty,
            onClose: () => Navigator.of(context).pop(),
          ),
          _ => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: slideshowFade,
                  child: _Slide(
                    key: ValueKey(_index),
                    item: _items[_index],
                    options: show.options,
                    // Each photo zooms for its time and the fades around it.
                    zoomFor:
                        Duration(seconds: show.options.photoSeconds) +
                        slideshowFade * 2,
                    zoomOut: _index.isOdd,
                    paused: _paused || _ended,
                    onVideoDone: _next,
                  ),
                ),
                if (_ended)
                  _EndOverlay(
                    canSave: _savedId == null,
                    onReplay: () => unawaited(_replay()),
                    onSave: () => unawaited(_save()),
                    onClose: () => Navigator.of(context).pop(),
                  )
                else
                  _Controls(
                    visible: _controlsVisible,
                    title: show.title,
                    position: _index,
                    count: _items.length,
                    paused: _paused,
                    canSave: _savedId == null,
                    onClose: () => Navigator.of(context).pop(),
                    onPrevious: _previous,
                    onTogglePause: _togglePause,
                    onNext: _next,
                    onSave: () => unawaited(_save()),
                  ),
              ],
            ),
          ),
        },
      ),
    );
  }
}

/// One item: a photo (with its slow zoom for Ken Burns) or a muted video.
class _Slide extends ConsumerStatefulWidget {
  const _Slide({
    required this.item,
    required this.options,
    required this.zoomFor,
    required this.zoomOut,
    required this.paused,
    required this.onVideoDone,
    super.key,
  });

  final MediaItem item;
  final SlideshowOptions options;
  final Duration zoomFor;

  /// Whether the photo starts zoomed in and zooms out, for variety.
  final bool zoomOut;
  final bool paused;
  final VoidCallback onVideoDone;

  @override
  ConsumerState<_Slide> createState() => _SlideState();
}

class _SlideState extends ConsumerState<_Slide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _zoom = AnimationController(
    vsync: this,
    duration: widget.zoomFor,
  );
  VideoPlayerController? _video;
  var _videoDone = false;

  bool get _kenBurns =>
      widget.options.transition == SlideshowTransition.kenBurns;

  @override
  void initState() {
    super.initState();
    if (widget.item.isVideo) {
      unawaited(_openVideo());
    } else if (_kenBurns && !widget.paused) {
      _zoom.forward();
    }
  }

  Future<void> _openVideo() async {
    try {
      final uri = await ref.read(mediaSourceProvider).videoUri(widget.item);
      if (uri == null) throw StateError('No URI for ${widget.item.id}');
      final controller = VideoPlayerController.contentUri(uri);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setVolume(0);
      controller.addListener(_onVideoTick);
      setState(() => _video = controller);
      if (!widget.paused) await controller.play();
    } on Object {
      // Unreadable: go on with the next item.
      _finishVideo();
    }
  }

  void _onVideoTick() {
    final value = _video?.value;
    if (value == null || !value.isInitialized) return;
    const limit = Duration(seconds: SlideshowOptions.maxVideoSeconds);
    final end = value.duration < limit ? value.duration : limit;
    if (value.position >= end || value.isCompleted) _finishVideo();
  }

  void _finishVideo() {
    if (_videoDone) return;
    _videoDone = true;
    unawaited(_video?.pause());
    // After this frame: the player rebuilds with the next item.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onVideoDone());
  }

  @override
  void didUpdateWidget(_Slide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused == widget.paused) return;
    if (widget.paused) {
      _zoom.stop();
      unawaited(_video?.pause());
    } else {
      if (_kenBurns && !widget.item.isVideo) _zoom.forward();
      if (!_videoDone) unawaited(_video?.play());
    }
  }

  @override
  void dispose() {
    _zoom.dispose();
    _video?.removeListener(_onVideoTick);
    unawaited(_video?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(mediaSourceProvider);
    final item = widget.item;
    final video = _video;
    if (item.isVideo) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: video == null
              ? Image(
                  image: source.thumbnail(item, size: 512),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                )
              : AspectRatio(
                  aspectRatio: video.value.aspectRatio,
                  child: VideoPlayer(video),
                ),
        ),
      );
    }
    final image = Image(
      image: source.preview(
        item,
        longestSide: viewerPreviewSide(context, item),
      ),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) => frame == null && !sync
          ? Image(image: source.thumbnail(item, size: 256), fit: BoxFit.contain)
          : child,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: !_kenBurns
            ? image
            : AnimatedBuilder(
                animation: _zoom,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(_zoom.value);
                  final progress = widget.zoomOut ? 1 - t : t;
                  final scale = 1 + 0.12 * progress;
                  // A slight drift, alternating sides from one photo to the
                  // next.
                  final drift = (widget.zoomOut ? -1 : 1) * 0.03 * progress;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translateByDouble(
                        drift * MediaQuery.sizeOf(context).width,
                        0,
                        0,
                        1,
                      )
                      ..scaleByDouble(scale, scale, 1, 1),
                    child: child,
                  );
                },
                child: image,
              ),
      ),
    );
  }
}

/// Controls shown on a tap: close and title at the top, previous, pause
/// and next at the bottom, *Save* when it is not saved yet.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.visible,
    required this.title,
    required this.position,
    required this.count,
    required this.paused,
    required this.canSave,
    required this.onClose,
    required this.onPrevious,
    required this.onTogglePause,
    required this.onNext,
    required this.onSave,
  });

  final bool visible;
  final String? title;
  final int position;
  final int count;
  final bool paused;
  final bool canSave;
  final VoidCallback onClose;
  final VoidCallback onPrevious;
  final VoidCallback onTogglePause;
  final VoidCallback onNext;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const white = Colors.white;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Color(0x00000000), Color(0x99000000)],
              stops: [0, 0.5, 1],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: l10n.actionClose,
                      color: white,
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                    Expanded(
                      child: Text(
                        title ?? '',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (canSave)
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: white),
                        onPressed: onSave,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: Text(l10n.actionSave),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  l10n.slideshowPosition(position + 1, count),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: l10n.slideshowPrevious,
                      color: white,
                      iconSize: 32,
                      onPressed: onPrevious,
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                    const SizedBox(width: 24),
                    IconButton.filled(
                      tooltip: paused
                          ? l10n.slideshowPlay
                          : l10n.slideshowPause,
                      iconSize: 40,
                      onPressed: onTogglePause,
                      icon: Icon(
                        paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      ),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      tooltip: l10n.slideshowNext,
                      color: white,
                      iconSize: 32,
                      onPressed: onNext,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the end of a slideshow offers: replay, save, close.
class _EndOverlay extends StatelessWidget {
  const _EndOverlay({
    required this.canSave,
    required this.onReplay,
    required this.onSave,
    required this.onClose,
  });

  final bool canSave;
  final VoidCallback onReplay;
  final VoidCallback onSave;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: const Color(0xB3000000),
      child: Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: onReplay,
              icon: const Icon(Icons.replay_rounded),
              label: Text(l10n.slideshowReplay),
            ),
            if (canSave)
              FilledButton.tonalIcon(
                onPressed: onSave,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(l10n.actionSave),
              ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              onPressed: onClose,
              child: Text(l10n.actionClose),
            ),
          ],
        ),
      ),
    );
  }
}

/// A message instead of the slideshow, with a close button.
class _Message extends StatelessWidget {
  const _Message({required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                onPressed: onClose,
                child: Text(AppLocalizations.of(context).actionClose),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
