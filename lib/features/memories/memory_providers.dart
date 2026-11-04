import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/memory.dart';
import 'package:clean_gallery/features/memories/memory_finder.dart';
import 'package:clean_gallery/features/slideshow/slideshow_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_providers.g.dart';

/// Builds slideshows from the media index.
@Riverpod(keepAlive: true)
SlideshowBuilder slideshowBuilder(Ref ref) => SlideshowBuilder(
  index: ref.watch(mediaIndexRepositoryProvider),
  trash: ref.watch(trashRepositoryProvider),
  slideshows: ref.watch(slideshowRepositoryProvider),
  memories: ref.watch(memoryRepositoryProvider),
);

/// Finds memories in the media index.
@Riverpod(keepAlive: true)
MemoryFinder memoryFinder(Ref ref) => MemoryFinder(
  index: ref.watch(mediaIndexRepositoryProvider),
  builder: ref.watch(slideshowBuilderProvider),
);

/// Today's memories, found once the media index is ready and again when a
/// duplicate scan ends (it measures blur and finds duplicates); each new
/// one is recorded for the *Memories* list. None while memories are off.
@Riverpod(keepAlive: true)
Future<List<Memory>> todaysMemories(Ref ref) async {
  final off = ref.watch(
    appSettingsControllerProvider.select(
      (s) => s.memories == MemoriesFrequency.off,
    ),
  );
  final ready = ref.watch(mediaIndexProvider.select((s) => s.ready));
  ref.watch(duplicateScanProvider.select((s) => s.running));
  if (off || !ready) return const [];
  final found = await ref.read(memoryFinderProvider).find(DateTime.now());
  await ref.read(memoryRepositoryProvider).record(found);
  return found;
}

/// Memories shown as cards at the top of the Camera tab: today's, unless
/// dismissed, most recent year first.
@riverpod
List<Memory> memoryCards(Ref ref) {
  final today = ref.watch(todaysMemoriesProvider).value ?? const <Memory>[];
  final stored = ref.watch(storedMemoriesProvider).value;
  if (today.isEmpty || stored == null) return const [];
  final shown = {for (final memory in stored) memory.key};
  return [
    for (final memory in today)
      if (shown.contains(memory.key)) memory,
  ];
}
