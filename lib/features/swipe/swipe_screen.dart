import 'dart:async';
import 'dart:math' as math;

import 'package:clean_gallery/core/brand/empty_state.dart';
import 'package:clean_gallery/core/brand/glass.dart';
import 'package:clean_gallery/core/brand/petal_mark.dart';
import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/core/theme/app_motion.dart';
import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/features/swipe/swipe_session.dart';
import 'package:clean_gallery/features/swipe/swipe_source.dart';
import 'package:clean_gallery/features/viewer/zoomable_image.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Share of the card width a drag must reach to sort the card.
const _sortDistance = 0.3;

/// Horizontal speed, in logical pixels per second, that sorts the card
/// whatever the distance (a flick).
const _sortSpeed = 800.0;

/// Duration of a card flying away, springing back or coming back.
const _motion = Duration(milliseconds: 260);

/// How a card released early comes back.
final _bounce = SpringCurve(AppMotion.springBouncy);

/// Swipe mode: the items of [source], one full-screen card at a time,
/// oldest first. Swipe left to move to the trash, right to keep; the
/// buttons do the same, plus a heart that keeps the item as a favorite.
/// **Undo** is always visible and brings the last card back.
///
/// The session is saved as it goes and resumes when the same source is
/// opened again; it ends on a summary. See `docs/features/swipe.md`.
class SwipeScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [source], titled [title].
  const SwipeScreen({required this.source, required this.title, super.key});

  /// What the session goes through.
  final SwipeSource source;

  /// Name of the source, e.g. "All photos" or a folder name.
  final String title;

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  final _deck = GlobalKey<_SwipeDeckState>();

  SwipeSession get _session =>
      ref.read(swipeSessionProvider(widget.source).notifier);

  Future<void> _decide(SwipeAction action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    unawaited(HapticFeedback.lightImpact());
    final done = await _session.decide(action);
    if (!done) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.favoriteDeclined)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(swipeSessionProvider(widget.source));
    final value = session.value;
    final canUndo = value != null && value.decisions.isNotEmpty;

    final colors = AppTheme.dark().colorScheme;
    // Always dark, like every screen around a photo.
    return Theme(
      data: AppTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: colors.surfaceContainerLowest,
          body: switch (session) {
            AsyncData(value: final state)
                when state.total > 0 && state.finished =>
              _Summary(
                state: state,
                title: widget.title,
                onRestart: _session.restart,
                onUndo: canUndo ? _session.undo : null,
              ),
            _ => SafeArea(
              child: Column(
                children: [
                  _Header(
                    title: widget.title,
                    onUndo: canUndo ? _session.undo : null,
                  ),
                  if (value != null && value.total > 0)
                    _Progress(done: value.done, total: value.total),
                  Expanded(
                    child: switch (session) {
                      AsyncData(value: final state) when state.total == 0 =>
                        Center(
                          child: EmptyState(
                            title: l10n.swipeEmpty,
                            padding: const EdgeInsets.all(32),
                          ),
                        ),
                      AsyncData(value: final state) => Stack(
                        fit: StackFit.expand,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                            child: _SwipeDeck(
                              key: _deck,
                              state: state,
                              onDecide: _decide,
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: _Buttons(
                              current: state.current,
                              onPressed: (action) =>
                                  _deck.currentState?.fly(action),
                            ),
                          ),
                        ],
                      ),
                      AsyncError() => _ErrorMessage(title: l10n.swipeError),
                      _ => const Center(child: CircularProgressIndicator()),
                    },
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
  }
}

/// Close, the name of the source, and Undo.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onUndo, this.foreground});

  final String title;
  final VoidCallback? onUndo;

  /// Color of the text and icons; the theme's by default.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.swipeClose,
            color: foreground,
            onPressed: () => context.pop(),
            icon: const Icon(Icons.close_rounded),
          ),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(color: foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Always visible, so the last decision is one tap away.
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: foreground),
            onPressed: onUndo,
            icon: const Icon(Icons.undo_rounded),
            label: Text(l10n.actionUndo),
          ),
        ],
      ),
    );
  }
}

/// "42 / 300" and a thin bar.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.swipeProgress(done, total),
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

/// The current card, draggable, over the next one.
class _SwipeDeck extends ConsumerStatefulWidget {
  const _SwipeDeck({required this.state, required this.onDecide, super.key});

  final SwipeSessionState state;

  /// Called once the current card has flown away.
  final void Function(SwipeAction action) onDecide;

  @override
  ConsumerState<_SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends ConsumerState<_SwipeDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _motion)
        ..addListener(_onTick)
        ..addStatusListener(_onStatus);

  /// Where the current card is, from the center.
  Offset _offset = Offset.zero;

  /// Animation the card follows, if any.
  Animation<Offset>? _path;

  /// Decision whose card is flying away.
  SwipeAction? _leaving;

  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    // A card returned from the summary starts where it left, then comes back
    // after this frame: the motion settings are not readable yet.
    final returned = widget.state.returned;
    if (returned != null && returned.item.id == widget.state.current?.id) {
      _offset = _away(returned.action, 400, 600);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _comeBackIfReturned(null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheNext());
  }

  @override
  void didUpdateWidget(_SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.current?.id != widget.state.current?.id) {
      _comeBackIfReturned(oldWidget.state.current);
      WidgetsBinding.instance.addPostFrameCallback((_) => _precacheNext());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// After an undo, the card comes back from the side it left.
  void _comeBackIfReturned(MediaItem? previous) {
    final returned = widget.state.returned;
    if (returned == null || returned.item.id != widget.state.current?.id) {
      return;
    }
    if (previous?.id == returned.item.id) return;
    final width = _size.width == 0 ? 400.0 : _size.width;
    final height = _size.height == 0 ? 600.0 : _size.height;
    _animate(_away(returned.action, width, height), Offset.zero);
  }

  /// Off-screen point a card of [action] flies to: left for the trash,
  /// right to keep, up for a favorite.
  static Offset _away(SwipeAction action, double width, double height) =>
      switch (action) {
        SwipeAction.trash => Offset(-width * 1.5, 0),
        SwipeAction.keep => Offset(width * 1.5, 0),
        SwipeAction.favorite => Offset(0, -height * 1.5),
      };

  /// Sorts the current card with [action]: it flies away, then
  /// [_SwipeDeck.onDecide] is called.
  void fly(SwipeAction action) {
    if (widget.state.current == null || _leaving != null) return;
    _leaving = action;
    _animate(_offset, _away(action, _size.width, _size.height) + _offset);
  }

  void _animate(Offset from, Offset to, {bool bounce = false}) {
    _path = Tween(begin: from, end: to).animate(
      CurvedAnimation(
        parent: _controller,
        curve: bounce ? _bounce : AppMotion.curve,
      ),
    );
    _controller.duration = AppMotion.of(
      context,
      bounce ? _bounce.duration : _motion,
    );
    setState(() => _offset = from);
    _controller.forward(from: 0);
  }

  void _onTick() {
    if (_path case final path?) setState(() => _offset = path.value);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _path = null;
    final leaving = _leaving;
    if (leaving == null) return;
    _leaving = null;
    // The next card takes the center in the same frame.
    setState(() => _offset = Offset.zero);
    widget.onDecide(leaving);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_leaving != null) return;
    _controller.stop();
    _path = null;
    setState(() => _offset += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_leaving != null) return;
    final speed = details.velocity.pixelsPerSecond.dx;
    final far = _offset.dx.abs() > _size.width * _sortDistance;
    if (far || speed.abs() > _sortSpeed) {
      final right = far ? _offset.dx > 0 : speed > 0;
      fly(right ? SwipeAction.keep : SwipeAction.trash);
    } else {
      _animate(_offset, Offset.zero, bounce: true);
    }
  }

  void _precacheNext() {
    if (!mounted) return;
    final source = ref.read(mediaSourceProvider);
    for (final item in widget.state.remaining.skip(1).take(2)) {
      unawaited(
        precacheImage(
          item.isVideo
              ? source.thumbnail(item, size: 512)
              : source.preview(
                  item,
                  longestSide: viewerPreviewSide(context, item),
                ),
          context,
          onError: (_, _) {},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.state.current;
    final next = widget.state.remaining.length > 1
        ? widget.state.remaining[1]
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        final progress = (_offset.distance / (_size.width * _sortDistance))
            .clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (next != null)
              Transform.scale(
                scale: 0.94 + 0.06 * progress,
                child: _Card(key: ValueKey('next-${next.id}'), item: next),
              ),
            if (current != null)
              GestureDetector(
                key: const ValueKey('swipe-card'),
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Transform.translate(
                  offset: _offset,
                  child: Transform.rotate(
                    angle: _offset.dx / _size.width * 0.3,
                    child: _Card(
                      key: ValueKey('card-${current.id}'),
                      item: current,
                      trash: (-_offset.dx / (_size.width * _sortDistance))
                          .clamp(0.0, 1.0),
                      keep: (_offset.dx / (_size.width * _sortDistance)).clamp(
                        0.0,
                        1.0,
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

/// One card: the photo (or a video's thumbnail) with its date and size,
/// and the Trash and Keep stamps showing as it is dragged.
class _Card extends ConsumerWidget {
  const _Card({required this.item, this.trash = 0, this.keep = 0, super.key});

  final MediaItem item;

  /// Opacity of the Trash stamp, 0 to 1.
  final double trash;

  /// Opacity of the Keep stamp, 0 to 1.
  final double keep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final source = ref.watch(mediaSourceProvider);
    final placeholder = Image(
      image: source.thumbnail(item, size: 256),
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
    final image = item.isVideo
        ? Image(
            image: source.thumbnail(item, size: 512),
            fit: BoxFit.contain,
            frameBuilder: (context, child, frame, sync) =>
                frame == null && !sync ? placeholder : child,
          )
        : Image(
            image: source.preview(
              item,
              longestSide: viewerPreviewSide(context, item),
            ),
            fit: BoxFit.contain,
            frameBuilder: (context, child, frame, sync) =>
                frame == null && !sync ? placeholder : child,
            errorBuilder: (context, error, stackTrace) => placeholder,
          );

    return Semantics(
      label: formatMediaDate(context, item.takenAt),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.black, child: image),
              if (item.isVideo)
                const Center(
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    size: 64,
                    color: Colors.white70,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x99000000)],
                    ),
                  ),
                  child: Padding(
                    // Above the floating buttons.
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 104),
                    child: Text(
                      '${formatMediaDate(context, item.takenAt)}  ·  '
                      '${formatBytes(context, item.sizeBytes)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              if (trash > 0)
                _Stamp(
                  label: l10n.swipeStampTrash,
                  color: colors.error,
                  foreground: colors.onError,
                  opacity: trash,
                  alignment: Alignment.topRight,
                ),
              if (keep > 0)
                _Stamp(
                  label: l10n.swipeStampKeep,
                  color: colors.primaryContainer,
                  foreground: colors.onPrimaryContainer,
                  opacity: keep,
                  alignment: Alignment.topLeft,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Trash" or "Keep" stamped over the card while it is dragged, tilted away
/// from the middle.
class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.label,
    required this.color,
    required this.foreground,
    required this.opacity,
    required this.alignment,
  });

  final String label;
  final Color color;
  final Color foreground;
  final double opacity;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: alignment.x < 0 ? -0.08 : 0.08,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Trash, favorite and keep buttons in a floating glass bar, for users who do
/// not swipe. Trash is a bin on the left, Keep a check on the right: they
/// differ by icon and position as well as by color.
class _Buttons extends StatelessWidget {
  const _Buttons({required this.current, required this.onPressed});

  final MediaItem? current;
  final void Function(SwipeAction action) onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final enabled = current != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassPill(
        height: 80,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filled(
                tooltip: l10n.swipeTrash,
                iconSize: 28,
                style: IconButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                  fixedSize: const Size.square(64),
                ),
                onPressed: enabled ? () => onPressed(SwipeAction.trash) : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                tooltip: l10n.swipeFavorite,
                iconSize: 22,
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceContainerHighest,
                  foregroundColor: colors.onSurface,
                  fixedSize: const Size.square(48),
                ),
                onPressed: enabled
                    ? () => onPressed(SwipeAction.favorite)
                    : null,
                icon: Icon(
                  current?.isFavorite ?? false
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                tooltip: l10n.swipeKeep,
                iconSize: 28,
                style: IconButton.styleFrom(
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  fixedSize: const Size.square(64),
                ),
                onPressed: enabled ? () => onPressed(SwipeAction.keep) : null,
                icon: const Icon(Icons.check_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// End of a session, the reward: the screen turns sun from the side the last
/// card left by, then the rosace completes, last petal lit. Shows what was
/// kept, trashed and favorited.
class _Summary extends StatefulWidget {
  const _Summary({
    required this.state,
    required this.title,
    required this.onRestart,
    required this.onUndo,
  });

  final SwipeSessionState state;
  final String title;
  final VoidCallback onRestart;
  final VoidCallback? onUndo;

  @override
  State<_Summary> createState() => _SummaryState();
}

class _SummaryState extends State<_Summary>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..addStatusListener((_) => setState(() {}));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reveal.isAnimating || _reveal.isCompleted) return;
    if (AppMotion.reduced(context)) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final origin = switch (widget.state.decisions.lastOrNull?.action) {
      SwipeAction.keep => Alignment.centerRight,
      SwipeAction.trash => Alignment.centerLeft,
      _ => Alignment.topCenter,
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: AnimatedBuilder(
        animation: _reveal,
        builder: (context, child) => ClipPath(
          clipper: _GrowingCircle(
            origin: origin,
            progress: AppMotion.curve.transform(_reveal.value),
          ),
          child: child,
        ),
        child: ColoredBox(
          color: AppColors.sun,
          child: SafeArea(
            child: _SummaryContent(
              state: widget.state,
              title: widget.title,
              onRestart: widget.onRestart,
              onUndo: widget.onUndo,
              showMark: _reveal.isCompleted,
            ),
          ),
        ),
      ),
    );
  }
}

/// A circle growing from [origin] until it covers the whole box.
class _GrowingCircle extends CustomClipper<Path> {
  const _GrowingCircle({required this.origin, required this.progress});

  final Alignment origin;
  final double progress;

  @override
  Path getClip(Size size) {
    if (progress >= 1) return Path()..addRect(Offset.zero & size);
    return Path()..addOval(
      Rect.fromCircle(
        center: origin.alongSize(size),
        radius: size.longestSide * 1.2 * progress,
      ),
    );
  }

  @override
  bool shouldReclip(_GrowingCircle old) => old.progress != progress;
}

class _SummaryContent extends ConsumerWidget {
  const _SummaryContent({
    required this.state,
    required this.title,
    required this.onRestart,
    required this.onUndo,
    required this.showMark,
  });

  final SwipeSessionState state;
  final String title;
  final VoidCallback onRestart;
  final VoidCallback? onUndo;
  final bool showMark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final trashed = state.decided(SwipeAction.trash);
    final freed = trashed.fold(0, (sum, item) => sum + item.sizeBytes);
    final kept = state.decided(SwipeAction.keep).length;
    final favorites = state.decided(SwipeAction.favorite).length;
    final counts = theme.textTheme.titleSmall?.copyWith(color: AppColors.ink);
    Widget line(List<String> parts) => Wrap(
      children: [
        for (final (i, part) in parts.indexed) ...[
          if (i > 0) Text('  ·  ', style: counts),
          Text(part, style: counts),
        ],
      ],
    );

    return Column(
      children: [
        _Header(title: title, onUndo: onUndo, foreground: AppColors.ink),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Center(
                      child: SizedBox.square(
                        dimension: _markSize(constraints),
                        child: showMark
                            ? BloomingMark(
                                size: _markSize(constraints),
                                colors: List.filled(petalCount, AppColors.ink),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.swipeDoneTitle,
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: AppColors.ink,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 16),
                        line([
                          l10n.swipeSummaryTrashed(trashed.length),
                          if (trashed.isNotEmpty) formatBytes(context, freed),
                        ]),
                        const SizedBox(height: 4),
                        line([
                          l10n.swipeSummaryKept(kept),
                          l10n.swipeSummaryFavorites(favorites),
                        ]),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.ink,
                              foregroundColor: AppColors.sun,
                            ),
                            onPressed: () => context.pop(),
                            child: Text(l10n.swipeDone),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              if (trashed.isNotEmpty)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.ink,
                                  ),
                                  onPressed: () =>
                                      context.go(AlbumRoutes.trash),
                                  child: Text(l10n.swipeOpenTrash),
                                ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.ink,
                                ),
                                onPressed: onRestart,
                                child: Text(l10n.swipeRestart),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// As wide as the screen allows, leaving room for the rest on small ones.
  static double _markSize(BoxConstraints constraints) =>
      math.min(constraints.maxWidth - 48, constraints.maxHeight * 0.44);
}

/// An error instead of the cards. An error is not a brand moment: an icon in
/// the error color, without the mark.
class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
