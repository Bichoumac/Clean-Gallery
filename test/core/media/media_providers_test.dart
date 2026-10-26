import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  group('stepColumns', () {
    test('moves by one within 2–6', () {
      expect(stepColumns(4, -1), 3);
      expect(stepColumns(4, 1), 5);
    });

    test('clamps at the limits', () {
      expect(stepColumns(minGridColumns, -1), minGridColumns);
      expect(stepColumns(maxGridColumns, 1), maxGridColumns);
    });
  });

  test('formatDuration', () {
    expect(formatDuration(Duration.zero), '0:00');
    expect(formatDuration(const Duration(seconds: 75)), '1:15');
    expect(formatDuration(const Duration(hours: 1, seconds: 5)), '1:00:05');
  });

  group('MediaList', () {
    late AppDatabase db;
    late ProviderContainer container;

    Future<void> index(List<MediaItem> items) async {
      final source = FakeMediaSource(items: items);
      db = inMemoryDatabase();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          mediaSourceProvider.overrideWithValue(source),
          permissionServiceProvider.overrideWithValue(FakePermissionService()),
          // An empty trash, without Drift streams.
          trashedIdsProvider.overrideWith((ref) => Stream.value(<String>{})),
        ],
      );
      addTearDown(db.close);
      addTearDown(container.dispose);
      await container.read(mediaIndexProvider.notifier).sync();
    }

    test('shows the first chunk, then the rest', () async {
      await index(List.generate(2500, testItem));
      final sizes = <int>[];
      container.listen(
        mediaListProvider(MediaSelection.all),
        (_, next) => sizes.add(next.value?.length ?? 0),
        fireImmediately: true,
      );

      final first = await container.read(
        mediaListProvider(MediaSelection.all).future,
      );
      expect(first, hasLength(mediaChunkSize));

      // Let the rest load.
      await pumpEventQueue();
      final all = container.read(mediaListProvider(MediaSelection.all)).value!;
      expect(all, hasLength(2500));
      // Same capture date: by id, newest (largest) first.
      expect(all.first.id, '2499');
      expect(all.last.id, '0');
      expect(sizes, containsAllInOrder([1000, 2500]));
    });

    test('reloads in place when the index changes', () async {
      await index([testItem(1), testItem(2)]);
      final states = <AsyncValue<List<MediaItem>>>[];
      container.listen(
        mediaListProvider(MediaSelection.photos),
        (_, next) => states.add(next),
      );
      await container.read(mediaListProvider(MediaSelection.photos).future);

      await container.read(mediaIndexRepositoryProvider).remove([1]);
      container.read(mediaIndexProvider.notifier).changed();
      await pumpEventQueue();

      final items = container.read(mediaListProvider(MediaSelection.photos));
      expect(items.value!.map((i) => i.id), ['2']);
      // No loading state in between: the grid keeps its scroll position.
      expect(states.whereType<AsyncLoading<List<MediaItem>>>(), isEmpty);
    });
  });
}
