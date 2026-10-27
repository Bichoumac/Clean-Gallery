import 'dart:async';

import 'package:clean_gallery/core/media/media_actions.dart';
import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/features/viewer/video_page.dart';
import 'package:clean_gallery/features/viewer/zoomable_image.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-screen viewer: swipe between the items of a selection.
///
/// Opened from a grid with [ViewerArgs]; reads the same media list as the
/// grid, so no item is loaded twice. Tapping toggles the controls and the
/// system bars. Always dark, whatever the app theme, so photos stand out.
class ViewerScreen extends ConsumerStatefulWidget {
  /// Creates the viewer.
  const ViewerScreen({required this.args, super.key});

  /// Selection to browse and item to open first.
  final ViewerArgs args;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  late final _pages = PageController(initialPage: widget.args.initialIndex);
  late int _index = widget.args.initialIndex;
  bool _controlsVisible = true;
  bool _zoomed = false;
  bool _precachedInitial = false;
  bool _closing = false;

  @override
  void dispose() {
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
          backgroundColor: Colors.black,
          body: items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _pages,
                      physics: _zoomed
                          ? const NeverScrollableScrollPhysics()
                          : const PageScrollPhysics(),
                      itemCount: items.length,
                      onPageChanged: (i) {
                        setState(() {
                          _index = i;
                          _zoomed = false;
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
                    // Pinned to the top with its own height: a full-screen
                    // overlay would swallow page swipes and video controls.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        ignoring: !_controlsVisible,
                        child: AnimatedOpacity(
                          opacity: _controlsVisible ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: _TopBar(item: items[index]),
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

/// Back button, date and file name over a dark gradient.
/// Back button, date and file name, and the actions on the current item:
/// share, favorite, move to trash. Edit and info come in M6.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
              IconButton(
                tooltip: l10n.actionTrash,
                color: Colors.white,
                onPressed: () => trashWithUndo(context, ref, [item]),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
