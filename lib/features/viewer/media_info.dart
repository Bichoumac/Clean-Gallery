import 'package:clean_gallery/analysis/image_quality.dart';
import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/media_metadata.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_info.g.dart';

/// What the info panel shows beyond the [MediaItem] itself: where its date
/// comes from, the camera metadata, and whether the location could be
/// read at all.
typedef MediaInfo = ({
  DateSource? dateSource,
  MediaMetadata metadata,
  bool locationAllowed,
});

/// [MediaInfo] of [item], read when its info panel opens: the date source
/// from the media index, the rest from the file's header.
@riverpod
Future<MediaInfo> mediaInfo(Ref ref, MediaItem item) async {
  final (dateSource, metadata, locationAllowed) = await (
    ref.watch(mediaIndexRepositoryProvider).dateSource(item.id),
    ref.watch(mediaSourceProvider).metadata(item),
    ref.watch(permissionServiceProvider).hasLocationAccess(),
  ).wait;
  return (
    dateSource: dateSource,
    metadata: metadata,
    locationAllowed: locationAllowed,
  );
}

/// [ImageQuality] of photo [item], measured when its info panel opens on
/// the same thumbnail and by the same code as the analysis engine, or
/// `null` without a readable thumbnail. Shown so the blur thresholds can
/// be checked on real photos.
@riverpod
Future<ImageQuality?> photoQuality(Ref ref, MediaItem item) async {
  final thumbnails = await ref.watch(mediaSourceProvider).grayThumbnails([
    item,
  ], side: perceptualThumbnailSide);
  final thumbnail = thumbnails[item.id];
  return thumbnail == null ? null : imageQuality(thumbnail);
}
