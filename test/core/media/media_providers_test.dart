import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/album.dart';
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

  test('MediaList shows the first chunk, then streams the rest', () async {
    final source = FakeMediaSource(items: List.generate(2500, testItem));
    final db = inMemoryDatabase();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaSourceProvider.overrideWithValue(source),
        // Chunked loading only: an empty trash, without Drift streams.
        trashedIdsProvider.overrideWith((ref) => Stream.value(<String>{})),
      ],
    );
    addTearDown(db.close);
    addTearDown(container.dispose);
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

    // Let the remaining chunks load.
    await pumpEventQueue();
    final all = container.read(mediaListProvider(MediaSelection.all)).value!;
    expect(all, hasLength(2500));
    expect(all.map((i) => i.id).take(3), ['0', '1', '2']);
    expect(all.last.id, '2499');
    expect(source.loads, [(0, 1000), (1000, 2000), (2000, 2500)]);
    expect(sizes, containsAllInOrder([1000, 2000, 2500]));
  });

  test('MediaList of a small library loads in one call', () async {
    final source = FakeMediaSource(items: [testItem(1), testItem(2)]);
    final db = inMemoryDatabase();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaSourceProvider.overrideWithValue(source),
        // Chunked loading only: an empty trash, without Drift streams.
        trashedIdsProvider.overrideWith((ref) => Stream.value(<String>{})),
      ],
    );
    addTearDown(db.close);
    addTearDown(container.dispose);
    // Listen, so the auto-dispose list is not released while it loads.
    container.listen(mediaListProvider(MediaSelection.photos), (_, _) {});
    final items = await container.read(
      mediaListProvider(MediaSelection.photos).future,
    );
    expect(items, hasLength(2));
    expect(source.loads, [(0, 2)]);
  });
}
