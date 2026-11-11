import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/media/retrying_image.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/theme/app_motion.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hero tag linking a grid thumbnail to the viewer page of the same item.
String mediaHeroTag(MediaItem item) => 'media-${item.id}';

/// Curve of the photo flying between its thumbnail and the viewer: quick
/// out of the grid, long soft landing, no overshoot (a spring overshot on
/// one side only, since the thumbnail is rarely centered).
const Curve mediaHeroCurve = AppMotion.viewerCurve;

/// Flight path of [item] between its thumbnail and the viewer.
///
/// The viewer's hero fills the screen while the photo inside only fills its
/// own proportions. The flight ends (or starts) on the photo itself, so the
/// square crop of the thumbnail opens into the whole photo without a jump.
CreateRectTween mediaHeroRectTween(MediaItem item) =>
    (begin, end) =>
        _PhotoRectTween(begin: begin, end: end, aspectRatio: item.aspectRatio);

/// What flies between the grid and the viewer: the thumbnail, cropped to
/// the shape of the flight, so the photo grows without black bands.
Widget mediaHeroShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final thumbnail = direction == HeroFlightDirection.push
      ? fromHeroContext.widget
      : toHeroContext.widget;
  return (thumbnail as Hero).child;
}

/// A [RectTween] between a thumbnail and the viewer's full-screen box that
/// moves to the photo's own frame inside that box.
///
/// Its [begin] and [end] stay the heroes' real boxes: the flight compares
/// [end] with where the viewer's hero is and would otherwise move it.
class _PhotoRectTween extends RectTween {
  _PhotoRectTween({
    required super.begin,
    required super.end,
    required this.aspectRatio,
  });

  final double aspectRatio;

  @override
  Rect? lerp(double t) {
    final begin = this.begin;
    final end = this.end;
    if (begin == null || end == null) return super.lerp(t);
    // The larger box is the viewer's.
    return begin.width * begin.height >= end.width * end.height
        ? Rect.lerp(_fitted(begin, aspectRatio), end, t)
        : Rect.lerp(begin, _fitted(end, aspectRatio), t);
  }

  // Tween.transform returns begin and end as they are at 0 and 1.
  @override
  Rect? transform(double t) => lerp(t);
}

/// Where a photo of [aspectRatio] shows inside [box], at its full size.
Rect _fitted(Rect box, double aspectRatio) {
  final size = applyBoxFit(
    BoxFit.contain,
    Size(aspectRatio, 1),
    box.size,
  ).destination;
  return Alignment.center.inscribe(size, box);
}

/// What a screen reader says about [item]: *Photo, date* or
/// *Video, duration, date*.
String mediaLabel(BuildContext context, MediaItem item) {
  final l10n = AppLocalizations.of(context);
  final date = formatMediaDate(context, item.takenAt);
  return item.isVideo
      ? l10n.mediaVideoLabel(formatDuration(item.duration), date)
      : l10n.mediaPhotoLabel(date);
}

/// Sizes a thumbnail may be asked for, in physical pixels: a few steps, so
/// the image cache keeps reusing them.
const thumbnailSteps = [192, 256, 320, 384, 512, 640, 768, 1024, 1280];

/// Smallest of [thumbnailSteps] covering [logicalSide] at
/// [devicePixelRatio], the largest one beyond: what a thumbnail
/// [logicalSide] wide asks for to stay sharp.
int thumbnailPixels(double logicalSide, double devicePixelRatio) {
  final needed = logicalSide * devicePixelRatio;
  for (final step in thumbnailSteps) {
    if (step >= needed) return step;
  }
  return thumbnailSteps.last;
}

/// Square thumbnail of a photo or video, with a duration badge on videos,
/// a heart on favorites and, on the cover of a folded stack of duplicates,
/// the number of items in it.
class MediaThumbnail extends ConsumerWidget {
  /// Creates a thumbnail of [item], decoded at about [pixelSize] pixels,
  /// or at the size it is laid out at when [pixelSize] is `null`.
  const MediaThumbnail({
    required this.item,
    this.pixelSize,
    this.onTap,
    this.onSelect,
    this.hero = true,
    this.stackSize,
    super.key,
  });

  /// Number of items of the folded stack this thumbnail stands for, or
  /// `null` for a single item.
  final int? stackSize;

  /// Whether the image flies to the viewer. Turn it off where the same item
  /// can appear twice on one page (album covers), since Hero tags must be
  /// unique per route.
  final bool hero;

  /// Item to show.
  final MediaItem item;

  /// Thumbnail size requested from the platform, in physical pixels (the
  /// image's short side); `null` to follow the laid out size, see
  /// [thumbnailPixels].
  final int? pixelSize;

  /// Called when the thumbnail is tapped.
  final VoidCallback? onTap;

  /// Selects the item, for screen readers, as their long press. The grid's
  /// own long press, which selects by sliding, needs the finger's position
  /// and is hidden from them.
  final VoidCallback? onSelect;

  /// Size to ask for in [box]: its longest side, since the image is
  /// cropped to cover the whole box.
  static int _fitted(BuildContext context, BoxConstraints box) {
    final side = [
      box.maxWidth,
      box.maxHeight,
    ].where((v) => v.isFinite).fold<double>(0, (a, b) => a > b ? a : b);
    return thumbnailPixels(
      side == 0 ? 128 : side,
      MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final source = ref.watch(mediaSourceProvider);
    final stackSize = this.stackSize;
    final itemLabel = mediaLabel(context, item);
    final label = stackSize == null
        ? itemLabel
        : '$itemLabel, ${l10n.mediaStackLabel(stackSize)}';

    return Semantics(
      label: item.isFavorite ? '$label, ${l10n.mediaFavoriteLabel}' : label,
      button: onTap != null,
      image: true,
      onLongPress: onSelect,
      onLongPressHint: onSelect == null ? null : l10n.mediaSelectHint,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.surfaceContainerHigh),
            HeroMode(
              enabled: hero,
              child: Hero(
                tag: mediaHeroTag(item),
                createRectTween: mediaHeroRectTween(item),
                flightShuttleBuilder: mediaHeroShuttle,
                curve: mediaHeroCurve,
                child: LayoutBuilder(
                  builder: (context, box) => RetryingImage(
                    image: source.thumbnail(
                      item,
                      size: pixelSize ?? _fitted(context, box),
                    ),
                    failure: Icon(
                      item.isVideo
                          ? Icons.movie_outlined
                          : Icons.broken_image_outlined,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            if (item.isVideo)
              Positioned(
                right: 6,
                bottom: 6,
                child: _Badge(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 14),
                      const SizedBox(width: 2),
                      Text(formatDuration(item.duration)),
                    ],
                  ),
                ),
              ),
            if (stackSize != null)
              Positioned(
                top: 6,
                right: 6,
                child: _Badge(
                  color: colors.primaryContainer,
                  foreground: colors.onPrimaryContainer,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.filter_none_rounded, size: 12),
                      const SizedBox(width: 3),
                      Text('$stackSize'),
                    ],
                  ),
                ),
              ),
            if (item.isFavorite)
              const Positioned(
                left: 6,
                bottom: 6,
                child: _Badge(child: Icon(Icons.favorite_rounded, size: 14)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small pill over a thumbnail, translucent black unless [color] is given.
class _Badge extends StatelessWidget {
  const _Badge({required this.child, this.color, this.foreground});

  final Widget child;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final foreground = this.foreground ?? Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: IconTheme(
          data: IconThemeData(color: foreground),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
