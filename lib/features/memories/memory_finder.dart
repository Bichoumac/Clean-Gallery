import 'package:clean_gallery/analysis/memories.dart';
import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/memory.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:clean_gallery/features/slideshow/slideshow_builder.dart';

/// Finds the memories of a day from the capture dates in the media index:
/// for each year back, the week and the day of that date, kept when they
/// have enough good photos ([pickMemories]).
///
/// Runs only while the app is open (ADR 0027). Good photos are the
/// camera's photos that a memory slideshow plays: not trashed, not blurry
/// or dark, one per duplicate group.
final class MemoryFinder {
  /// Creates a finder.
  const MemoryFinder({required this.index, required this.builder});

  /// The media index.
  final MediaIndexRepository index;

  /// Counts the good photos of a period.
  final SlideshowBuilder builder;

  /// Options counting photos only, duplicates and blurry ones left out.
  static const _photosOnly = SlideshowOptions(includeVideos: false);

  /// The memories of [day], most recent year first.
  Future<List<Memory>> find(DateTime day) async {
    const camera = MediaSelection.camera;
    final oldest = await index.oldest(camera);
    if (oldest == null) return const [];
    final periods = memoryPeriods(day, oldest: oldest.takenAt);
    final counts = <String, int>{};
    int? weekCount;
    for (final period in periods) {
      // Periods come as the week, then its day: a day cannot have more good
      // photos than its week.
      if (period.kind == MemoryKind.onThisDay &&
          (weekCount ?? 0) < period.minPhotos) {
        continue;
      }
      final selection = camera.copyWith(dates: period.dates);
      final count = (await builder.goodItems(selection, _photosOnly)).length;
      counts[period.key] = count;
      if (period.kind == MemoryKind.thisWeek) weekCount = count;
    }
    return pickMemories(periods, counts);
  }
}
