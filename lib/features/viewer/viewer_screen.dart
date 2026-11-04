import 'dart:async';
import 'dart:math' as math;

import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_actions.dart';
import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/core/theme/app_motion.dart';
import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/duplicate_group.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/features/user_albums/user_album_actions.dart';
import 'package:clean_gallery/features/viewer/group_strip.dart';
import 'package:clean_gallery/features/viewer/info_panel.dart';
import 'package:clean_gallery/features/viewer/video_page.dart';
import 'package:clean_gallery/features/viewer/zoomable_image.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full-screen viewer: swipe between the items of a selection.
///
/// Opened from a grid with [ViewerArgs]; reads the same media list as the
/// grid, so no item is loaded twice. Tapping toggles the controls and the
/// system bars. Always dark, whatever the app theme, so photos stand out.
///
/// When the item shown is in a duplicate group, a [GroupStrip] at the
/// bottom shows the group and sorts it photo by photo (keep or trash).
class ViewerScreen extends ConsumerStatefulWidget {
  /// Creates the viewer.
  const ViewerScreen({required this.args, super.key});

  /// Selection to browse and item to open first.
  final ViewerArgs args;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen>
    with SingleTickerProviderStateMixin {
  /// Share of the screen height a pull must reach to close the viewer.
  static const _pullDistance = 0.25;

  /// Downward speed, in logical pixels per second, that closes the viewer
  /// whatever the distance (a flick).
  static const _pullSpeed = 700.0;

  /// How far the photo is pulled down, in logical pixels.
  final _pull = ValueNotifier<double>(0);

  /// Brings the photo back after a pull released early.
  late final AnimationController _pullBack = AnimationController.unbounded(
    vsync: this,
  )..addListener(() => _pull.value = _pullBack.value);

  late final _pages = PageController(initialPage: widget.args.initialIndex);
  late int _index = widget.args.initialIndex;
  bool _controlsVisible = true;
  bool _zoomed = false;
  bool _precachedInitial = false;
  bool _closing = false;

  /// Read in [initState]: `ref` cannot be used in [dispose].
  late final DuplicateScan _scan;

  /// Duplicate group shown in the strip, as when the viewer reached it, so
  /// it stays while its items go to the trash.
  DuplicateGroup? _group;

  /// Id of the item [_group] was looked up for; `null` to look it up again
  /// for the item shown.
  String? _groupFor;

  /// Ids kept and trashed from the strip in [_group], and the items
  /// trashed, last one last, for Undo.
  Set<String> _kept = {};
  Set<String> _trashed = {};
  List<MediaItem> _trashLog = [];

  /// Id of the item to show once the list is updated (after a trash or an
  /// undo), or `null`.
  String? _pendingTarget;

  @override
  void initState() {
    super.initState();
    // The analysis would compete with the photos for MediaStore's
    // thumbnail rendering.
    _scan = ref.read(duplicateScanProvider.notifier)..pause();
  }

  @override
  void dispose() {
    _scan.resume();
    _pullBack.dispose();
    _pull.dispose();
    _pages.dispose();
    // Leave the viewer with system bars and free rotation restored.
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(SystemChrome.setPreferredOrientations(const []));
    super.dispose();
  }

  /// Starts loading the previews of the photos around [index], so swiping
  /// shows a ready image instead of the thumbnail placeholder.
  ///
  /// Waits for the preview of the photo shown first: the native loader
  /// serves the newest request first, so neighbors asked at once would
  /// delay it.
  Future<void> _precacheNeighbors(List<MediaItem> items, int index) async {
    final source = ref.read(mediaSourceProvider);
    Future<void> precache(int i) async {
      if (i < 0 || i >= items.length || items[i].isVideo || !mounted) return;
      final side = viewerPreviewSide(context, items[i]);
      await precacheImage(
        source.preview(items[i], longestSide: side),
        context,
        onError: (_, _) {},
      );
    }

    await precache(index);
    if (!mounted || _index != index) return;
    for (final i in [index + 1, index - 1, index + 2]) {
      unawaited(precache(i));
    }
  }

  /// Shows [item]: its page when it is in the list, or a viewer of its own
  /// otherwise (a copy in another folder than the grid's).
  void _open(MediaItem item, List<MediaItem> items) {
    final i = items.indexWhere((it) => it.id == item.id);
    if (i >= 0) {
      _pages.jumpToPage(i);
      return;
    }
    context.pushReplacement(
      AppRoutes.viewer,
      extra: ViewerArgs(
        selection: MediaSelection(ids: [item.id]),
        initialIndex: 0,
      ),
    );
  }

  /// The item of [_group] after [current] still to sort (neither kept nor
  /// trashed), going round the group, or `null` when there is none.
  MediaItem? _nextToSort(String current) {
    final members = _group?.items ?? const <MediaItem>[];
    final start = members.indexWhere((m) => m.id == current);
    for (var step = 1; step < members.length; step++) {
      final member = members[(start + step) % members.length];
      if (!_kept.contains(member.id) && !_trashed.contains(member.id)) {
        return member;
      }
    }
    return null;
  }

  void _keep(MediaItem item, List<MediaItem> items) {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _kept = {..._kept, item.id});
    if (_nextToSort(item.id) case final next?) _open(next, items);
  }

  Future<void> _trash(MediaItem item) async {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _trashed = {..._trashed, item.id};
      _kept = {..._kept}..remove(item.id);
      _trashLog = [..._trashLog, item];
      _pendingTarget = _nextToSort(item.id)?.id;
    });
    await ref.read(mediaActionsProvider).trash([item]);
  }

  Future<void> _restore(MediaItem item) async {
    setState(() {
      _trashed = {..._trashed}..remove(item.id);
      _trashLog = [
        for (final i in _trashLog)
          if (i.id != item.id) i,
      ];
      _pendingTarget = item.id;
    });
    await ref.read(mediaActionsProvider).restore([item.id]);
  }

  /// Opens the document scanner on [photo], then shows the page it saved.
  Future<void> _scanDocument(MediaItem photo) async {
    final saved = await context.push<String>(AppRoutes.scan, extra: photo);
    if (saved != null && mounted) setState(() => _pendingTarget = saved);
  }

  /// Opens the editor on [photo], then shows the photo it saved.
  Future<void> _edit(MediaItem photo) async {
    final saved = await context.push<String>(AppRoutes.editor, extra: photo);
    if (saved != null && mounted) setState(() => _pendingTarget = saved);
  }

  /// Whether the grid behind is drawn. The route stays opaque otherwise, so
  /// the grid does not cost anything while photos are looked at.
  void _showBehind({required bool show}) {
    ModalRoute.of(context)?.overlayEntries.first.opaque = !show;
  }

  void _onPullStart(DragStartDetails details) {
    _pullBack.stop();
    _showBehind(show: true);
  }

  void _onPullUpdate(DragUpdateDetails details) {
    _pull.value = math.max(0, _pull.value + (details.primaryDelta ?? 0));
  }

  void _onPullEnd(DragEndDetails details) {
    final speed = details.primaryVelocity ?? 0;
    final height = MediaQuery.sizeOf(context).height;
    if (_pull.value > height * _pullDistance || speed > _pullSpeed) {
      // The hero flies back to its thumbnail from where the photo is now.
      _closing = true;
      Navigator.of(context).maybePop();
    } else if (AppMotion.reduced(context)) {
      _pull.value = 0;
      _showBehind(show: false);
    } else {
      _pullBack
          .animateWith(
            SpringSimulation(AppMotion.spring, _pull.value, 0, speed),
          )
          .whenCompleteOrCancel(() {
            if (mounted && _pull.value == 0) _showBehind(show: false);
          });
    }
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        _controlsVisible
            ? SystemUiMode.edgeToEdge
            : SystemUiMode.immersiveSticky,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items =
        ref.watch(visibleMediaListProvider(widget.args.selection)).value ??
        const <MediaItem>[];
    final index = items.isEmpty ? 0 : _index.clamp(0, items.length - 1);
    final loaded = ref
        .watch(visibleMediaListProvider(widget.args.selection))
        .hasValue;
    if (loaded && items.isEmpty && !_closing) {
      // Everything was moved to the trash: nothing left to show.
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
    final groups = ref.watch(libraryGroupsByItemProvider).value;
    if (_groupFor == null && groups != null && items.isNotEmpty) {
      final current = items[index];
      _group = groups[current.id];
      _groupFor = current.id;
      _kept = {};
      _trashed = {};
      _trashLog = [];
    }
    if (_pendingTarget case final target?) {
      final i = items.indexWhere((it) => it.id == target);
      if (i >= 0) {
        _pendingTarget = null;
        if (i != index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pages.hasClients) _pages.jumpToPage(i);
          });
        }
      }
    }
    final group = _group;
    final shown = items.isEmpty ? null : items[index];
    final inGroup =
        shown != null && (group?.items.any((m) => m.id == shown.id) ?? false);
    if (!_precachedInitial && items.isNotEmpty) {
      _precachedInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_precacheNeighbors(items, index));
      });
    }

    return Theme(
      data: AppTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          // The grid shows behind while a photo is pulled down.
          backgroundColor: Colors.transparent,
          body: items.isEmpty
              ? const ColoredBox(
                  color: Colors.black,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Stack(
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: _pull,
                      builder: (context, pull, _) => Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(
                            alpha: (1 - _pullProgress(context, pull) * 3).clamp(
                              0.0,
                              1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _Pullable(
                      pull: _pull,
                      // Photos only, at 1× zoom: a zoomed photo pans.
                      enabled: !_zoomed && !(shown?.isVideo ?? true),
                      onStart: _onPullStart,
                      onUpdate: _onPullUpdate,
                      onEnd: _onPullEnd,
                      child: PageView.builder(
                        controller: _pages,
                        physics: _zoomed
                            ? const NeverScrollableScrollPhysics()
                            : const PageScrollPhysics(),
                        itemCount: items.length,
                        onPageChanged: (i) {
                          setState(() {
                            _index = i;
                            _zoomed = false;
                            // Within the group the strip stays; elsewhere the
                            // group of the new item is looked up.
                            final inStrip =
                                _group?.items.any((m) => m.id == items[i].id) ??
                                false;
                            _groupFor = inStrip ? items[i].id : null;
                          });
                          unawaited(_precacheNeighbors(items, i));
                        },
                        itemBuilder: (context, i) {
                          final item = items[i];
                          return item.isVideo
                              ? VideoPage(
                                  key: ValueKey(item.id),
                                  item: item,
                                  isCurrent: i == index,
                                  controlsVisible: _controlsVisible,
                                  onTap: _toggleControls,
                                  bottomInset: _actionBarHeight,
                                )
                              : ZoomableImage(
                                  key: ValueKey(item.id),
                                  item: item,
                                  onTap: _toggleControls,
                                  onZoomChanged: (zoomed) =>
                                      setState(() => _zoomed = zoomed),
                                );
                        },
                      ),
                    ),
                    // Pinned to the top with its own height: a full-screen
                    // overlay would swallow page swipes and video controls.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _FadesWithPull(
                        pull: _pull,
                        child: IgnorePointer(
                          ignoring: !_controlsVisible,
                          child: AnimatedOpacity(
                            opacity: _controlsVisible ? 1 : 0,
                            duration: AppMotion.of(context, AppMotion.standard),
                            child: _TopBar(
                              item: items[index],
                              onScan: () => _scanDocument(items[index]),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // The group strip, then the actions, pinned to the
                    // bottom with their own height like the top bar.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _FadesWithPull(
                        pull: _pull,
                        child: IgnorePointer(
                          ignoring: !_controlsVisible,
                          child: AnimatedOpacity(
                            opacity: _controlsVisible ? 1 : 0,
                            duration: AppMotion.of(context, AppMotion.standard),
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black54, Colors.transparent],
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Not over a video's playback controls.
                                  if (group != null &&
                                      shown != null &&
                                      !shown.isVideo)
                                    GroupStrip(
                                      group: group,
                                      current: inGroup ? shown.id : '',
                                      kept: _kept,
                                      trashed: _trashed,
                                      onOpen: (item) => _open(item, items),
                                      onRestore: (item) =>
                                          unawaited(_restore(item)),
                                      onKeep: inGroup
                                          ? () => _keep(shown, items)
                                          : null,
                                      onTrash: inGroup
                                          ? () => unawaited(_trash(shown))
                                          : null,
                                      onUndo: _trashLog.isEmpty
                                          ? null
                                          : () => unawaited(
                                              _restore(_trashLog.last),
                                            ),
                                    ),
                                  _ActionBar(
                                    item: items[index],
                                    onEdit: () => _edit(items[index]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// How far [pull] is, from 0 to a whole screen height.
double _pullProgress(BuildContext context, double pull) =>
    (pull / MediaQuery.sizeOf(context).height).clamp(0.0, 1.0);

/// The pages of the viewer: a vertical drag moves and shrinks them.
///
/// The drag is only listened to when [enabled]. It competes with the page
/// view's horizontal drag and the photo's zoom in the gesture arena: the
/// direction of the finger picks the page view or the pull, a second finger
/// picks the zoom.
class _Pullable extends StatelessWidget {
  const _Pullable({
    required this.pull,
    required this.enabled,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.child,
  });

  final ValueListenable<double> pull;
  final bool enabled;
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('viewer-pull'),
    onVerticalDragStart: enabled ? onStart : null,
    onVerticalDragUpdate: enabled ? onUpdate : null,
    onVerticalDragEnd: enabled ? onEnd : null,
    child: ValueListenableBuilder<double>(
      valueListenable: pull,
      child: child,
      builder: (context, value, child) {
        final scale = 1 - _pullProgress(context, value) * 0.4;
        return Transform.translate(
          offset: Offset(0, value),
          child: Transform.scale(scale: scale, child: child),
        );
      },
    ),
  );
}

/// [child], fading out as soon as a photo is pulled down.
class _FadesWithPull extends StatelessWidget {
  const _FadesWithPull({required this.pull, required this.child});

  final ValueListenable<double> pull;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: pull,
    child: child,
    builder: (context, value, child) => Opacity(
      opacity: (1 - _pullProgress(context, value) * 8).clamp(0.0, 1.0),
      child: child,
    ),
  );
}

/// Back button, date and file name over a dark gradient. The actions are
/// in the [_ActionBar] at the bottom.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.item, required this.onScan});

  final MediaItem item;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fileName = item.fileName;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
          child: Row(
            children: [
              const BackButton(color: Colors.white),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatMediaDate(context, item.takenAt),
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    if (fileName != null)
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
              if (!item.isVideo)
                IconButton(
                  tooltip: AppLocalizations.of(context).scanAction,
                  color: Colors.white,
                  onPressed: onScan,
                  icon: const Icon(Icons.document_scanner_outlined),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Height of the [_ActionBar], above the system navigation bar.
const _actionBarHeight = 64.0;

/// The actions on the item shown, at the bottom of the screen within reach
/// of the thumb: share, favorite, edit (photos), add to album, details,
/// move to trash.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.item, required this.onEdit});

  final MediaItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: _actionBarHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: l10n.actionShare,
              color: Colors.white,
              onPressed: () => shareWithOptions(context, ref, [item]),
              icon: const Icon(Icons.share_rounded),
            ),
            IconButton(
              tooltip: item.isFavorite
                  ? l10n.actionUnfavorite
                  : l10n.actionFavorite,
              color: Colors.white,
              onPressed: () => toggleFavorite(context, ref, [item]),
              icon: Icon(
                item.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
            ),
            if (!item.isVideo)
              IconButton(
                tooltip: l10n.actionEdit,
                color: Colors.white,
                onPressed: onEdit,
                icon: const Icon(Icons.tune_rounded),
              ),
            IconButton(
              tooltip: l10n.actionAddToAlbum,
              color: Colors.white,
              onPressed: () => addToAlbum(context, ref, [item]),
              icon: const Icon(Icons.library_add_outlined),
            ),
            IconButton(
              tooltip: l10n.actionInfo,
              color: Colors.white,
              onPressed: () => showInfoPanel(context, item),
              icon: const Icon(Icons.info_outline_rounded),
            ),
            IconButton(
              tooltip: l10n.actionTrash,
              color: Colors.white,
              onPressed: () => trashWithUndo(context, ref, [item]),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
