import 'package:clean_gallery/analysis/memories.dart';
import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/duplicate_repository.dart';
import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/core/database/memory_repository.dart';
import 'package:clean_gallery/core/database/slideshow_repository.dart';
import 'package:clean_gallery/core/database/trash_repository.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/memory.dart';
import 'package:clean_gallery/domain/ritual.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:clean_gallery/features/memories/memory_finder.dart';
import 'package:clean_gallery/features/slideshow/slideshow_builder.dart';
import 'package:clean_gallery/platform/media_source.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late MediaIndexRepository index;
  late SlideshowBuilder builder;
  final day = DateTime(2026, 10, 20, 12);

  Future<void> indexItems(List<MediaItem> items) => index.upsert([
    for (final item in items)
      IndexedMedia(
        item: item,
        albumId: 'camera',
        albumName: 'Camera',
        revision: 1,
      ),
  ]);

  /// Marks [blurry] photos as blurry and the others of [photos] as sharp.
  Future<void> measure(
    List<MediaItem> photos, {
    Set<String> blurry = const {},
  }) => DuplicateRepository(db).savePhotoAnalysis(photos, {
    for (final photo in photos)
      photo.id: (
        hashes: (dHash: 0, pHash: 0),
        quality: (
          sharpness: blurry.contains(photo.id) ? 5.0 : 500.0,
          brightness: 120.0,
          contrast: 40.0,
        ),
      ),
  });

  /// Stores a duplicate group of [ids], the first suggested.
  Future<void> storeGroup(List<int> ids) async {
    final id = await db
        .into(db.duplicateGroups)
        .insert(
          DuplicateGroupsCompanion.insert(
            kind: DuplicateKind.burst,
            computedAt: day,
          ),
        );
    for (final (i, asset) in ids.indexed) {
      await db
          .into(db.duplicateMembers)
          .insert(
            DuplicateMembersCompanion.insert(
              groupId: id,
              assetId: asset,
              isSuggestedKeep: Value(i == 0),
            ),
          );
    }
  }

  setUp(() {
    db = inMemoryDatabase();
    index = MediaIndexRepository(db);
    builder = SlideshowBuilder(
      index: index,
      trash: TrashRepository(db),
      slideshows: SlideshowRepository(db),
      memories: MemoryRepository(db),
    );
  });
  tearDown(() => db.close());

  List<String> ids(List<MediaItem> items) => [for (final i in items) i.id];

  test('oldest first, without trashed, blurry or duplicate items', () async {
    final photos = [
      for (var id = 1; id <= 5; id++)
        testItem(id, takenAt: day.subtract(Duration(minutes: id))),
    ];
    final video = testItem(
      6,
      takenAt: day.add(const Duration(minutes: 1)),
      duration: const Duration(seconds: 30),
    );
    await indexItems([...photos, video]);
    await measure(photos, blurry: {'2'});
    await storeGroup([3, 4]);
    await TrashRepository(db).trash([photos[4]], retentionDays: 30);

    const selection = MediaSelection(albumId: 'camera');
    final built = await builder.build(
      const SelectionSlideshow(selection, title: 'Camera'),
      const SlideshowOptions(),
    );
    // 5 trashed, 2 blurry, one of 3 and 4 (duplicates); the video last
    // (newest).
    final shown = ids(built.items);
    expect(shown, hasLength(3));
    expect(shown.last, '6');
    expect(shown[1], '1');
    expect(['3', '4'], contains(shown.first));
    expect(built.title, 'Camera');

    final everything = await builder.goodItems(
      selection,
      const SlideshowOptions(
        skipDuplicatesAndBlurry: false,
        includeVideos: false,
      ),
    );
    expect(ids(everything), ['4', '3', '2', '1']);
  });

  test('shuffled keeps the same items', () async {
    await indexItems([
      for (var id = 1; id <= 6; id++)
        testItem(id, takenAt: day.subtract(Duration(minutes: id))),
    ]);
    final built = await builder.build(
      const PickedSlideshow(['1', '2', '3', '4', '5', '6'], title: ''),
      const SlideshowOptions(order: SlideshowOrder.shuffled),
    );
    expect(ids(built.items), unorderedEquals(['1', '2', '3', '4', '5', '6']));
  });

  test('a saved slideshow plays in its order with its options', () async {
    await indexItems([
      for (var id = 1; id <= 3; id++)
        testItem(id, takenAt: day.subtract(Duration(minutes: id))),
    ]);
    const options = SlideshowOptions(photoSeconds: 8);
    final id = await SlideshowRepository(db)
        .save('Trip', options, ['2', '9', '1', '3']);
    await TrashRepository(db).trash([testItem(3)], retentionDays: 30);
    final built = await builder.build(
      SavedSlideshowSource(id),
      const SlideshowOptions(),
    );
    // 9 left the device, 3 is in the trash.
    expect(ids(built.items), ['2', '1']);
    expect(built.options, options);
    expect(built.savedId, id);
    expect(built.title, 'Trip');
  });

  test('a ritual on a deleted album plays nothing', () async {
    final ritual = await MemoryRepository(db).addRitual(
      const Ritual(
        id: 0,
        content: RitualContent.userAlbum,
        targetId: 42,
        time: RecurringTime(repeat: Repeat.weekly, day: 7, minute: 0),
      ),
    );
    final built = await builder.build(
      RitualSlideshow(ritual),
      const SlideshowOptions(),
    );
    expect(built.items, isEmpty);
    expect(
      (await builder.build(
        const RitualSlideshow(99),
        const SlideshowOptions(),
      )).items,
      isEmpty,
    );
  });

  group('memory finder', () {
    // Wednesday 4 November 2026.
    final today = DateTime(2026, 11, 4, 9);

    test('finds the day, else the week, of each year', () async {
      final items = [
        // 1 year ago: 6 photos on 4 November 2025.
        for (var i = 0; i < minDayPhotos; i++)
          testItem(100 + i, takenAt: DateTime(2025, 11, 4, 10, i)),
        // 2 years ago: 8 photos across the week of 4 November 2024, none
        // that day.
        for (var i = 0; i < minWeekPhotos; i++)
          testItem(200 + i, takenAt: DateTime(2024, 11, 6, 10, i)),
        // 3 years ago: too few.
        for (var i = 0; i < 3; i++)
          testItem(300 + i, takenAt: DateTime(2023, 11, 4, 10, i)),
        // A screenshot does not count (not a camera photo).
        testItem(
          400,
          takenAt: DateTime(2023, 11, 4, 11),
          relativePath: 'DCIM/Screenshots/',
        ),
      ];
      await indexItems(items);
      final finder = MemoryFinder(index: index, builder: builder);
      final memories = await finder.find(today);
      expect(memories.map((m) => (m.kind, m.yearsAgo, m.count)), [
        (MemoryKind.onThisDay, 1, minDayPhotos),
        (MemoryKind.thisWeek, 2, minWeekPhotos),
      ]);
    });

    test('nothing in an empty library', () async {
      final finder = MemoryFinder(index: index, builder: builder);
      expect(await finder.find(today), isEmpty);
    });
  });
}
