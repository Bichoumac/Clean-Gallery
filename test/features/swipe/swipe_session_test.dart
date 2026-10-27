import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/features/swipe/swipe_session.dart';
import 'package:clean_gallery/features/swipe/swipe_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late FakePlatformBridge bridge;
  late ProviderContainer container;
  const all = SwipeSource.allPhotos();

  // Three photos taken a day apart, and a video the day after.
  final media = FakeMediaSource(
    items: [
      testItem(1, takenAt: DateTime(2026, 1, 3)),
      testItem(2, takenAt: DateTime(2026)),
      testItem(3, takenAt: DateTime(2026, 1, 2)),
      testItem(
        4,
        takenAt: DateTime(2026, 1, 4),
        duration: const Duration(seconds: 5),
      ),
    ],
  );

  ProviderContainer open() {
    final created = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaSourceProvider.overrideWithValue(media),
        permissionServiceProvider.overrideWithValue(FakePermissionService()),
        platformBridgeProvider.overrideWithValue(bridge),
      ],
    );
    addTearDown(created.dispose);
    // Keep the session alive between reads.
    created.listen(swipeSessionProvider(all), (_, _) {});
    return created;
  }

  setUp(() async {
    db = inMemoryDatabase();
    addTearDown(db.close);
    bridge = FakePlatformBridge();
    // Index first: an open container starts the session at once.
    final indexing = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaSourceProvider.overrideWithValue(media),
        permissionServiceProvider.overrideWithValue(FakePermissionService()),
        platformBridgeProvider.overrideWithValue(bridge),
      ],
    );
    await indexing.read(mediaIndexProvider.notifier).sync();
    indexing.dispose();
    container = open();
  });

  Future<SwipeSessionState> session([ProviderContainer? from]) =>
      (from ?? container).read(swipeSessionProvider(all).future);

  SwipeSession notifier() => container.read(swipeSessionProvider(all).notifier);

  Future<Set<String>> trashed() =>
      container.read(trashRepositoryProvider).trashedIds();

  test('all photos, oldest first, videos left out', () async {
    final state = await session();
    expect([for (final item in state.remaining) item.id], ['2', '3', '1']);
    expect(state.total, 3);
    expect(state.done, 0);
  });

  test('left trashes, right keeps, the heart keeps as a favorite', () async {
    await session();
    await notifier().decide(SwipeAction.trash);
    await notifier().decide(SwipeAction.keep);
    await notifier().decide(SwipeAction.favorite);
    final state = await session();
    expect(state.finished, isTrue);
    expect(state.done, 3);
    expect(state.decided(SwipeAction.trash).single.id, '2');
    expect(state.decided(SwipeAction.keep).single.id, '3');
    expect(await trashed(), {'2'});
    final request = bridge.favoriteRequests.single;
    expect(request.$1, ['1']);
    expect(request.$2, isTrue);
  });

  test('undo brings the cards back, as many times as needed', () async {
    await session();
    await notifier().decide(SwipeAction.trash);
    await notifier().decide(SwipeAction.favorite);
    await notifier().undo();
    var state = await session();
    expect(state.current!.id, '3');
    expect(state.returned!.action, SwipeAction.favorite);
    expect(bridge.favoriteRequests.last.$1, ['3']);
    expect(bridge.favoriteRequests.last.$2, isFalse);

    await notifier().undo();
    state = await session();
    expect(state.current!.id, '2');
    expect(state.done, 0);
    expect(await trashed(), isEmpty, reason: 'restored from the trash');
    await notifier().undo();
    expect((await session()).current!.id, '2', reason: 'nothing left to undo');
  });

  test('a session resumes where it was left', () async {
    await session();
    await notifier().decide(SwipeAction.keep);
    await notifier().decide(SwipeAction.trash);
    // Undo right after a swipe removes that swipe.
    await notifier().undo();
    await notifier().decide(SwipeAction.keep);

    final again = open();
    final state = await session(again);
    expect(state.done, 2);
    expect(state.total, 3);
    expect(state.current!.id, '1');
    expect(await again.read(swipeProgressProvider.future), {'all': 2});
  });

  test('start over forgets the decisions, trashed items stay out', () async {
    await session();
    await notifier().decide(SwipeAction.trash);
    await notifier().decide(SwipeAction.keep);
    await notifier().restart();
    final state = await session();
    expect(state.done, 0);
    expect([for (final item in state.remaining) item.id], ['3', '1']);
  });

  test('sources round-trip through their key', () {
    for (final source in [
      const SwipeSource.allPhotos(),
      const SwipeSource.blurry(),
      const SwipeSource.screenshots(),
      SwipeSource.month(DateTime(2024, 3, 15)),
      const SwipeSource.folder('-1739773001'),
    ]) {
      expect(SwipeSource.parse(source.key), source);
    }
    expect(SwipeSource.month(DateTime(2024, 3)).key, 'month:2024-03');
    expect(SwipeSource.parse('month:2024-13'), isNull);
    expect(SwipeSource.parse('folder:'), isNull);
    expect(SwipeSource.parse('nothing'), isNull);
  });

  test('a month source holds the items of that month', () async {
    final january = SwipeSource.month(DateTime(2026));
    container.listen(swipeSessionProvider(january), (_, _) {});
    final state = await container.read(swipeSessionProvider(january).future);
    expect([for (final i in state.remaining) i.id], ['2', '3', '1', '4']);
    expect(await container.read(swipeMonthsProvider.future), [
      (month: DateTime(2026), count: 4),
    ]);
  });
}
