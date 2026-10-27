import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeMediaSource source;
  late ProviderContainer container;

  // 1 and 2 are the same photo in two folders; 3 has the same size but
  // other content; 4 has a size of its own.
  final camera = testItem(1, sizeBytes: 500, takenAt: DateTime(2026, 5));
  final copy = testItem(
    2,
    sizeBytes: 500,
    takenAt: DateTime(2026, 5),
    relativePath: 'Pictures/WhatsApp/',
  );
  final sameSize = testItem(3, sizeBytes: 500, takenAt: DateTime(2026, 4));
  final unique = testItem(4, sizeBytes: 900, takenAt: DateTime(2026, 3));

  setUp(() {
    db = inMemoryDatabase();
    source = FakeMediaSource(
      items: [camera, copy, sameSize, unique],
      folders: const [
        Album(id: 'cam', name: 'Camera', count: 0),
        Album(id: 'wa', name: 'WhatsApp', count: 0),
      ],
      folderItems: {
        'cam': [camera, sameSize, unique],
        'wa': [copy],
      },
    );
    source.hashes
      ..['1'] = 'aaa'
      ..['2'] = 'aaa';
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaSourceProvider.overrideWithValue(source),
        permissionServiceProvider.overrideWithValue(FakePermissionService()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> syncAndScan() async {
    await container.read(mediaIndexProvider.notifier).sync();
    await container.read(duplicateScanProvider.notifier).run();
  }

  Future<List<List<String>>> groups(MediaSelection base) async => [
    for (final group
        in await container
            .read(mediaIndexRepositoryProvider)
            .duplicateGroups(base))
      [for (final item in group.items) item.id],
  ];

  test('hashes only items sharing their size, then groups them', () async {
    await syncAndScan();
    expect(
      source.hashCalls.expand((ids) => ids),
      unorderedEquals(['1', '2', '3']),
    );
    expect(await groups(MediaSelection.all), [
      ['1', '2'],
    ]);
    final group = (await db.select(db.duplicateGroups).get()).single;
    expect(group.kind, DuplicateKind.exact);
  });

  test('a second scan reads no file again', () async {
    await syncAndScan();
    source.hashCalls.clear();
    await container.read(duplicateScanProvider.notifier).run();
    expect(source.hashCalls, isEmpty);
  });

  test('groups are filtered by the displayed folder', () async {
    await syncAndScan();
    // The copy is in another folder: no duplicate within Camera alone.
    expect(await groups(const MediaSelection(albumId: 'cam')), isEmpty);
    expect(await groups(MediaSelection.photos), hasLength(1));
  });

  test('trashed items leave their group, and undo brings it back', () async {
    await syncAndScan();
    final trash = container.read(trashRepositoryProvider);
    await trash.trash([copy], retentionDays: 30);
    expect(await groups(MediaSelection.all), isEmpty);
    await trash.restore(['2']);
    expect(await groups(MediaSelection.all), hasLength(1));
  });

  test('a changed file is hashed again', () async {
    await syncAndScan();
    source
      ..revisions['2'] = 2
      ..items = [
        camera,
        copy.copyWith(modifiedAt: DateTime(2026, 6)),
        sameSize,
        unique,
      ]
      ..hashes['2'] = 'bbb';
    source.hashCalls.clear();
    await syncAndScan();
    expect(source.hashCalls.expand((ids) => ids), ['2']);
    expect(await groups(MediaSelection.all), isEmpty);
  });

  test('shots of a burst form a group of their own', () async {
    final shots = [
      for (var i = 0; i < 3; i++)
        testItem(
          10 + i,
          sizeBytes: 700 + i,
          takenAt: DateTime(2026, 2),
        ).copyWith(fileName: '20260201_101500_00$i.jpg'),
    ];
    source.items = [...source.items, ...shots];
    await syncAndScan();
    final all = await container
        .read(mediaIndexRepositoryProvider)
        .duplicateGroups(MediaSelection.all);
    final burst = all.singleWhere((g) => g.kind == DuplicateKind.burst);
    expect(burst.items.map((i) => i.id), unorderedEquals(['10', '11', '12']));
    // Largest file kept: no thumbnail here, so no sharpness to compare.
    expect(burst.best.id, '12');
    // Different sizes: no file read for them.
    expect(source.hashCalls.expand((ids) => ids), isNot(contains('10')));
  });

  test('a burst saved twice is one exact group, not a burst', () async {
    final first = testItem(
      10,
      sizeBytes: 700,
    ).copyWith(fileName: '20260201_101500_001.jpg');
    final second = testItem(
      11,
      sizeBytes: 700,
    ).copyWith(fileName: '20260201_101500_002.jpg');
    source
      ..items = [first, second]
      ..hashes['10'] = 'x'
      ..hashes['11'] = 'x';
    await syncAndScan();
    final kinds = [
      for (final group in await db.select(db.duplicateGroups).get()) group.kind,
    ];
    expect(kinds, [DuplicateKind.exact]);
  });

  test('the favorite copy is the one to keep', () async {
    source.items = [camera, copy.copyWith(isFavorite: true), sameSize, unique];
    await syncAndScan();
    final group =
        (await container
                .read(mediaIndexRepositoryProvider)
                .duplicateGroups(MediaSelection.all))
            .single;
    expect(group.best.id, '2');
    expect(group.extras.map((i) => i.id), ['1']);
  });
}
