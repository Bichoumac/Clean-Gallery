import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/core/database/memory_repository.dart';
import 'package:clean_gallery/core/database/slideshow_repository.dart';
import 'package:clean_gallery/core/database/trash_repository.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/memory.dart';
import 'package:clean_gallery/domain/ritual.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:clean_gallery/platform/media_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late SlideshowRepository slideshows;
  final now = DateTime(2026, 11, 3, 12);

  setUp(() async {
    db = inMemoryDatabase();
    slideshows = SlideshowRepository(db);
    await MediaIndexRepository(db).upsert([
      for (var id = 1; id <= 4; id++)
        IndexedMedia(
          item: testItem(id, takenAt: now.subtract(Duration(hours: id))),
          albumId: 'camera',
          albumName: 'Camera',
          revision: 1,
        ),
    ]);
  });
  tearDown(() => db.close());

  group('saved slideshows', () {
    const options = SlideshowOptions(
      photoSeconds: 3,
      music: SlideshowMusic.device(uri: 'content://a', name: 'A'),
    );

    test('keep their order and options, newest first', () async {
      final first = await slideshows.save(' Trip ', options, [
        '3',
        '1',
        '2',
      ], now: now);
      final second = await slideshows.save('Other', const SlideshowOptions(), [
        '4',
      ], now: now.add(const Duration(minutes: 1)));
      expect(await slideshows.itemIds(first), ['3', '1', '2']);
      final list = await slideshows.watchSaved().first;
      expect(list.map((s) => s.id), [second, first]);
      expect(list.last.title, 'Trip');
      expect(list.last.options, options);
      expect(list.last.count, 3);
      expect(list.last.cover?.id, '3');
      expect((await slideshows.find(first))?.options, options);
      expect(await slideshows.deviceMusicUris(), {'content://a'});
    });

    test('trashed items are neither counted nor the cover', () async {
      final id = await slideshows.save('Trip', options, ['3', '1']);
      await TrashRepository(db)
          .trash([testItem(3)], retentionDays: 30, now: now);
      final saved = (await slideshows.watchSaved().first).single;
      expect(saved.count, 1);
      expect(saved.cover?.id, '1');
      // Still listed, and skipped while playing.
      expect(await slideshows.itemIds(id), ['3', '1']);
    });

    test('rename, delete and undo', () async {
      final id = await slideshows.save('Trip', options, ['1', '2']);
      await slideshows.rename(id, ' Summer ');
      expect((await slideshows.find(id))?.title, 'Summer');
      final deleted = await slideshows.delete(id);
      expect(await slideshows.find(id), isNull);
      expect(await db.select(db.slideshowItems).get(), isEmpty);
      await slideshows.restore(deleted!);
      expect(await slideshows.itemIds(id), ['1', '2']);
      expect(await slideshows.delete(999), isNull);
    });

    test('items deleted for good leave every slideshow', () async {
      final a = await slideshows.save('A', options, ['1', '2', '3']);
      final b = await slideshows.save('B', options, ['2']);
      await slideshows.forget(['2']);
      expect(await slideshows.itemIds(a), ['1', '3']);
      expect(await slideshows.itemIds(b), isEmpty);
    });
  });

  group('memories', () {
    Memory memory(String key, int years) => Memory(
      key: key,
      kind: MemoryKind.thisWeek,
      yearsAgo: years,
      dates: DateFilter.days(DateTime(2026 - years, 11, 2), now),
      count: 10,
    );

    test('are recorded once and listed until dismissed', () async {
      final memories = MemoryRepository(db);
      await memories.record([memory('a', 1), memory('b', 2)], now: now);
      await memories.setDismissed('b', dismissed: true);
      // Found again: stays dismissed.
      await memories.record([memory('b', 2), memory('c', 3)], now: now);
      final list = await memories.watchMemories().first;
      expect(list.map((m) => m.key), ['a', 'c']);
      expect(list.first.dates, memory('a', 1).dates);
      await memories.setDismissed('b', dismissed: false);
      expect(await memories.watchMemories().first, hasLength(3));
      expect((await memories.find('b'))?.yearsAgo, 2);
    });
  });

  group('rituals', () {
    test('add, change, delete and undo', () async {
      final memories = MemoryRepository(db);
      final id = await memories.addRitual(
        const Ritual(
          id: 0,
          content: RitualContent.lastWeek,
          time: RecurringTime(repeat: Repeat.weekly, day: 9, minute: 1140),
        ),
      );
      final ritual = (await memories.rituals()).single;
      expect(ritual.id, id);
      // The day was brought into range.
      expect(ritual.time.day, 7);
      await memories.updateRitual(
        ritual.copyWith(
          content: RitualContent.userAlbum,
          targetId: 4,
          enabled: false,
        ),
      );
      final changed = await memories.ritual(id);
      expect(changed?.targetId, 4);
      expect(changed?.enabled, isFalse);
      final row = await memories.deleteRitual(id);
      expect(await memories.rituals(), isEmpty);
      await memories.restoreRitual(row!);
      expect(await memories.ritual(id), changed);
    });
  });
}
