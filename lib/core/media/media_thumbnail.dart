import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/media/retrying_image.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hero tag linking a grid thumbnail to the viewer page of the same item.
String mediaHeroTag(MediaItem item) => 'media-${item.id}';

/// Square thumbnail of a photo or video, with a duration badge on videos,
/// a heart on favorites and, on the cover of a folded stack of duplicates,
/// the number of items in it.
class MediaThumbnail extends ConsumerWidget {
  /// Creates a thumbnail of [item], decoded at about [pixelSize] pixels.
  const MediaThumbnail({
    required this.item,
    required this.pixelSize,
    this.onTap,
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

  /// Thumbnail size requested from the platform, in physical pixels.
  final int pixelSize;

  /// Called when the thumbnail is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final source = ref.watch(mediaSourceProvider);
    final date = formatMediaDate(context, item.takenAt);
    final stackSize = this.stackSize;
    final itemLabel = item.isVideo
        ? l10n.mediaVideoLabel(formatDuration(item.duration), date)
        : l10n.mediaPhotoLabel(date);
    final label = stackSize == null
        ? itemLabel
        : '$itemLabel, ${l10n.mediaStackLabel(stackSize)}';

    return Semantics(
      label: item.isFavorite ? '$label, ${l10n.mediaFavoriteLabel}' : label,
      button: onTap != null,
      image: true,
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
                child: RetryingImage(
                  image: source.thumbnail(item, size: pixelSize),
                  failure: Icon(
                    item.isVideo
                        ? Icons.movie_outlined
                        : Icons.broken_image_outlined,
                    color: colors.onSurfaceVariant,
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
