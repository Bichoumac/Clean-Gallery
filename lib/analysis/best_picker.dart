import 'package:clean_gallery/domain/media_item.dart';

/// The item to keep among duplicates, by the brief's rules, in order:
///
/// 1. a favorite;
/// 2. the highest resolution;
/// 3. the sharpest, when [MediaItem.sharpness] is known for both;
/// 4. the largest file;
/// 5. the oldest capture date;
/// 6. the smallest id, usually the first copy on the device.
///
/// [items] must not be empty. See `docs/analysis-engine.md#best-pick`.
MediaItem pickBest(List<MediaItem> items) {
  assert(items.isNotEmpty, 'pickBest needs at least one item');
  return items.reduce((best, item) => _better(item, best) ? item : best);
}

/// [items] with the best one first, the others in their original order.
List<MediaItem> bestFirst(List<MediaItem> items) {
  final best = pickBest(items);
  return [best, ...items.where((item) => item.id != best.id)];
}

/// Whether [a] should be kept rather than [b].
bool _better(MediaItem a, MediaItem b) {
  if (a.isFavorite != b.isFavorite) return a.isFavorite;
  final pixels = (a.width * a.height).compareTo(b.width * b.height);
  if (pixels != 0) return pixels > 0;
  final sharpA = a.sharpness;
  final sharpB = b.sharpness;
  if (sharpA != null && sharpB != null && sharpA != sharpB) {
    return sharpA > sharpB;
  }
  if (a.sizeBytes != b.sizeBytes) return a.sizeBytes > b.sizeBytes;
  if (a.takenAt != b.takenAt) return a.takenAt.isBefore(b.takenAt);
  final idA = int.tryParse(a.id);
  final idB = int.tryParse(b.id);
  if (idA != null && idB != null) return idA < idB;
  return a.id.compareTo(b.id) < 0;
}
