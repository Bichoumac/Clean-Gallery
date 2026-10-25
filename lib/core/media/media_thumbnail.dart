import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hero tag linking a grid thumbnail to the viewer page of the same item.
String mediaHeroTag(MediaItem item) => 'media-${item.id}';

/// Square thumbnail of a photo or video, with a duration badge on videos
/// and a heart on favorites.
class MediaThumbnail extends ConsumerWidget {
  /// Creates a thumbnail of [item], decoded at about [pixelSize] pixels.
  const MediaThumbnail({
    required this.item,
    required this.pixelSize,
    this.onTap,
    this.hero = true,
    super.key,
  });

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
    final label = item.isVideo
        ? l10n.mediaVideoLabel(formatDuration(item.duration), date)
        : l10n.mediaPhotoLabel(date);

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
                child: Image(
                  image: source.thumbnail(item, size: pixelSize),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  // A request dropped by the native loader (scrolled past) is
                  // not a broken file: show the plain background.
                  errorBuilder: (context, error, stackTrace) =>
                      error is PlatformException && error.code == 'dropped'
                      ? const SizedBox.shrink()
                      : Icon(
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

/// Small translucent pill over a thumbnail.
class _Badge extends StatelessWidget {
  const _Badge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: IconTheme(
          data: const IconThemeData(color: Colors.white),
          child: DefaultTextStyle.merge(
            style: const TextStyle(
              color: Colors.white,
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
