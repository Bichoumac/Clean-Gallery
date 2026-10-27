import 'dart:async';

import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/app_router.dart';
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
    final theme = Theme.of(context);
    final session = ref.watch(swipeSessionProvider(widget.source));
    final value = session.value;
    final canUndo = value != null && value.decisions.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.swipeClose,
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Always visible, so the last decision is one tap away.
                  TextButton.icon(
                    onPressed: canUndo ? _session.undo : null,
                    icon: const Icon(Icons.undo_rounded),
                    label: Text(l10n.actionUndo),
                  ),
                ],
              ),
            ),
            if (value != null && value.total > 0)
              _Progress(done: value.done, total: value.total),
            Expanded(
              child: switch (session) {
                AsyncData(value: final state) when state.total == 0 => _Message(
                  icon: Icons.check_circle_outline_rounded,
                  title: l10n.swipeEmpty,
                ),
                AsyncData(value: final state) when state.finished => _Summary(
                  state: state,
                  onRestart: _session.restart,
                ),
                AsyncData(value: final state) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _SwipeDeck(
                    key: _deck,
                    state: state,
                    onDecide: _decide,
                  ),
                ),
                AsyncError() => _Message(
                  icon: Icons.error_outline_rounded,
                  title: l10n.swipeError,
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
            if (value != null && !value.finished)
              _Buttons(
                current: value.current,
                onPressed: (action) => _deck.currentState?.fly(action),
              ),
          ],
        ),
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
                minHeight: 6,
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
    _comeBackIfReturned(null);
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

  void _animate(Offset from, Offset to) {
    _path = Tween(
      begin: from,
      end: to,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
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
      _animate(_offset, Offset.zero);
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
          boxShadow: const [
            BoxShadow(blurRadius: 16, color: Color(0x33000000)),
          ],
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
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
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
                  opacity: trash,
                  alignment: Alignment.topRight,
                ),
              if (keep > 0)
                _Stamp(
                  label: l10n.swipeStampKeep,
                  color: colors.primary,
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

/// "Trash" or "Keep" written over the card while it is dragged.
class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.label,
    required this.color,
    required this.opacity,
    required this.alignment,
  });

  final String label;
  final Color color;
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              border: Border.all(color: color, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Trash, favorite and keep buttons, for users who do not swipe.
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
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton.outlined(
            tooltip: l10n.swipeTrash,
            iconSize: 32,
            padding: const EdgeInsets.all(16),
            color: colors.error,
            onPressed: enabled ? () => onPressed(SwipeAction.trash) : null,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          IconButton.filledTonal(
            tooltip: l10n.swipeFavorite,
            iconSize: 26,
            padding: const EdgeInsets.all(12),
            onPressed: enabled ? () => onPressed(SwipeAction.favorite) : null,
            icon: Icon(
              current?.isFavorite ?? false
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
          ),
          IconButton.filled(
            tooltip: l10n.swipeKeep,
            iconSize: 32,
            padding: const EdgeInsets.all(16),
            onPressed: enabled ? () => onPressed(SwipeAction.keep) : null,
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
    );
  }
}

/// End of a session: what was kept, trashed and favorited.
class _Summary extends ConsumerWidget {
  const _Summary({required this.state, required this.onRestart});

  final SwipeSessionState state;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final trashed = state.decided(SwipeAction.trash);
    final freed = trashed.fold(0, (sum, item) => sum + item.sizeBytes);
    final kept = state.decided(SwipeAction.keep).length;
    final favorites = state.decided(SwipeAction.favorite).length;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.celebration_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.swipeDoneTitle,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: Text(l10n.swipeSummaryTrashed(trashed.length)),
                    trailing: trashed.isEmpty
                        ? null
                        : Text(
                            formatBytes(context, freed),
                            style: theme.textTheme.titleMedium,
                          ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.check_rounded),
                    title: Text(l10n.swipeSummaryKept(kept)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.favorite_border_rounded),
                    title: Text(l10n.swipeSummaryFavorites(favorites)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.pop(),
              child: Text(l10n.swipeDone),
            ),
            const SizedBox(height: 8),
            if (trashed.isNotEmpty)
              TextButton(
                onPressed: () => context.go(AlbumRoutes.trash),
                child: Text(l10n.swipeOpenTrash),
              ),
            TextButton(onPressed: onRestart, child: Text(l10n.swipeRestart)),
          ],
        ),
      ),
    );
  }
}

/// An icon and a line of text, centered.
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title});

  final IconData icon;
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
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
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
