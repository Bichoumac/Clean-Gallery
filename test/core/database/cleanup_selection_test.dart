import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/features/cleanup/cleanup_lists.dart';
import 'package:clean_gallery/platform/media_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  const screen = (width: 1080, height: 2340);
  final today = DateTime(2026, 10, 27, 15);
  final old = DateTime(2026, 8);
  final recent = DateTime(2026, 10, 20);
  const megabyte = 1024 * 1024;

  late MediaIndexRepository repository;

  Future<void> index(List<MediaItem> items) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    repository = MediaIndexRepository(db, screen: screen);
    await repository.upsert([
      for (final item in items)
        IndexedMedia(
          item: item,
          albumId: item.relativePath,
          albumName: 'Folder',
          revision: 1,
        ),
    ]);
  }

  Future<List<String>> ids(CleanupList list) async => [
    for (final item in await repository.load(switch (list) {
      CleanupList.screenshots => oldScreenshots(ageDays: 30, today: today),
      CleanupList.largeVideos => largeVideos(megabytes: 100),
    }))
      item.id,
  ];

  test(
    'old screenshots: by folder, name or screen size, before the age',
    () async {
      await index([
        testItem(1, takenAt: old, relativePath: 'DCIM/Screenshots/'),
        testItem(
          2,
          takenAt: old,
          relativePath: 'Download/',
        ).copyWith(fileName: 'Screenshot_20260801-101010_Maps.jpg'),
        testItem(3, takenAt: old, relativePath: 'Pictures/App/').copyWith(
          fileName: 'export.png',
          mimeType: 'image/png',
          width: 1080,
          height: 2340,
        ),
        // Too recent.
        testItem(4, takenAt: recent, relativePath: 'DCIM/Screenshots/'),
        // A camera photo.
        testItem(5, takenAt: old),
        // A video in the Screenshots folder (a screen recording).
        testItem(
          6,
          takenAt: old,
          duration: const Duration(seconds: 5),
          relativePath: 'DCIM/Screenshots/',
        ),
      ]);
      expect(
        await ids(CleanupList.screenshots),
        unorderedEquals(['1', '2', '3']),
      );
    },
  );

  test('large videos: from the size, largest first', () async {
    const clip = Duration(minutes: 1);
    await index([
      testItem(1, duration: clip, sizeBytes: 150 * megabyte),
      testItem(2, duration: clip, sizeBytes: 900 * megabyte),
      testItem(3, duration: clip, sizeBytes: 100 * megabyte),
      testItem(4, duration: clip, sizeBytes: 99 * megabyte),
      // A large photo is not a video.
      testItem(5, sizeBytes: 200 * megabyte),
    ]);
    expect(await ids(CleanupList.largeVideos), ['2', '1', '3']);
  });
}
