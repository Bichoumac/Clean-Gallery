import 'package:clean_gallery/analysis/index_rules.dart';
import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  group('planIndexSync', () {
    test('describes new and changed items, newest first', () {
      final plan = planIndexSync(
        indexed: {1: 5, 2: 5, 3: null},
        current: {'4': 1, '3': 1, '2': 6, '1': 5},
      );
      expect(plan.changed, ['4', '3', '2']);
      expect(plan.removed, isEmpty);
    });

    test('removes items no longer on the device', () {
      final plan = planIndexSync(indexed: {1: 5, 2: 5}, current: {'2': 5});
      expect(plan.changed, isEmpty);
      expect(plan.removed, [1]);
    });

    test('describes everything with refreshAll', () {
      final plan = planIndexSync(
        indexed: {1: 5},
        current: {'1': 5},
        refreshAll: true,
      );
      expect(plan.changed, ['1']);
      expect(plan.refreshAll, isTrue);
    });
  });

  group('MediaIndex.sync', () {
    late AppDatabase db;
    late FakeMediaSource source;
    late FakePermissionService permissions;
    late ProviderContainer container;

    final library = [
      testItem(3, takenAt: DateTime(2026, 3)),
      testItem(2, takenAt: DateTime(2026, 2)),
      testItem(1, takenAt: DateTime(2026)),
    ];

    setUp(() {
      db = inMemoryDatabase();
      source = FakeMediaSource(items: [...library]);
      permissions = FakePermissionService();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          mediaSourceProvider.overrideWithValue(source),
          permissionServiceProvider.overrideWithValue(permissions),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    MediaIndex index() => container.read(mediaIndexProvider.notifier);

    Future<List<int>> indexedIds() async => [
      for (final row in await db.select(db.assets).get()) row.id,
    ];

    test('first sync indexes everything and becomes ready', () async {
      expect(container.read(mediaIndexProvider).ready, isFalse);
      await index().sync();
      expect(source.describeCalls, [
        ['3', '2', '1'],
      ]);
      expect(await indexedIds(), unorderedEquals([1, 2, 3]));
      expect(container.read(mediaIndexProvider).ready, isTrue);
      expect(
        container.read(appSettingsControllerProvider).mediaIndexVersion,
        '1',
      );
    });

    test('a sync with no change describes nothing', () async {
      await index().sync();
      final revision = container.read(mediaIndexProvider).revision;
      await index().sync();
      expect(source.describeCalls, hasLength(1));
      expect(container.read(mediaIndexProvider).revision, revision);
    });

    test('describes only changed items and removes missing ones', () async {
      await index().sync();
      source
        ..revisions['2'] = 2
        ..items = [library[0], library[1]];
      await index().sync();
      expect(source.describeCalls.last, ['2']);
      expect(await indexedIds(), unorderedEquals([2, 3]));
    });

    test('keeps analysis results unless the file changed', () async {
      await index().sync();
      await db
          .update(db.assets)
          .write(const AssetsCompanion(analysisVersion: Value(3)));
      source
        ..revisions['3'] = 2
        ..revisions['2'] = 2
        ..items = [
          // Favorite changed only.
          library[0].copyWith(isFavorite: true),
          // Content changed.
          library[1].copyWith(sizeBytes: 99),
          library[2],
        ];
      await index().sync();
      final rows = {
        for (final row in await db.select(db.assets).get()) row.id: row,
      };
      expect(rows[3]!.isFavorite, isTrue);
      expect(rows[3]!.analysisVersion, 3);
      expect(rows[2]!.analysisVersion, 0);
      expect(rows[1]!.analysisVersion, 3);
    });

    test('a new platform database version refreshes everything', () async {
      await index().sync();
      await db
          .update(db.assets)
          .write(const AssetsCompanion(analysisVersion: Value(3)));
      source.version = '2';
      await index().sync();
      expect(source.describeCalls.last, ['3', '2', '1']);
      final rows = await db.select(db.assets).get();
      expect(rows.map((r) => r.analysisVersion), everyElement(0));
    });

    test('does nothing without media access', () async {
      permissions.result = MediaAccess.denied;
      await index().sync();
      expect(source.snapshots, 0);
      expect(container.read(mediaIndexProvider).ready, isFalse);
    });

    test('with limited access, trashed items are kept', () async {
      await index().sync();
      await container.read(trashRepositoryProvider).trash([
        library[2],
      ], retentionDays: 30);
      permissions.result = MediaAccess.limited;
      source.items = [library[0]];
      await index().sync();
      expect(await indexedIds(), unorderedEquals([1, 3]));
    });

    test('resolves capture dates from file names', () async {
      final received = testItem(
        4,
        takenAt: DateTime(2026, 9, 1, 8),
      ).copyWith(fileName: 'IMG-20240315-WA0001.jpg');
      source
        ..items = [received, ...library]
        ..withoutMetadataDate.add('4');
      await index().sync();
      final row = await (db.select(
        db.assets,
      )..where((t) => t.id.equals(4))).getSingle();
      expect(row.captureAt, DateTime(2024, 3, 15, 12));
      expect(row.captureSource, DateSource.filename);
      expect(row.takenAt, DateTime(2026, 9, 1, 8));
      final camera = await (db.select(
        db.assets,
      )..where((t) => t.id.equals(1))).getSingle();
      expect(camera.captureSource, DateSource.exif);
    });

    test('new index rules apply to every item again', () async {
      await index().sync();
      expect(
        container.read(appSettingsControllerProvider).indexRules,
        indexRulesVersion,
      );
      await db
          .update(db.assets)
          .write(const AssetsCompanion(analysisVersion: Value(3)));
      await container
          .read(appSettingsControllerProvider.notifier)
          .setIndexRules(indexRulesVersion - 1);
      await index().sync();
      expect(source.describeCalls.last, ['3', '2', '1']);
      // Only dates are refreshed: analysis results are kept.
      final rows = await db.select(db.assets).get();
      expect(rows.map((r) => r.analysisVersion), everyElement(3));
    });

    test('calls during a sync are merged into one more pass', () async {
      final first = index().sync();
      final second = index().sync();
      await Future.wait([first, second]);
      expect(source.snapshots, 2);
      expect(container.read(mediaIndexProvider).syncing, isFalse);
    });
  });

  group('MediaIndexRepository', () {
    late AppDatabase db;
    late ProviderContainer container;

    final camera = testItem(1, takenAt: DateTime(2026, 5), sizeBytes: 300);
    final video = testItem(
      2,
      takenAt: DateTime(2026, 4),
      duration: const Duration(seconds: 9),
      sizeBytes: 100,
    );
    final screenshot = testItem(
      3,
      takenAt: DateTime(2026, 3),
      sizeBytes: 200,
      relativePath: 'Pictures/Screenshots/',
      isFavorite: true,
    );

    setUp(() async {
      db = inMemoryDatabase();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          mediaSourceProvider.overrideWithValue(
            FakeMediaSource(
              items: [camera, video, screenshot],
              folders: const [
                Album(id: 'cam', name: 'Camera', count: 0),
                Album(id: 'shots', name: 'Screenshots', count: 0),
              ],
              folderItems: {
                'cam': [camera, video],
                'shots': [screenshot],
              },
            ),
          ),
          permissionServiceProvider.overrideWithValue(FakePermissionService()),
        ],
      );
      await container.read(mediaIndexProvider.notifier).sync();
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<List<String>> ids(MediaSelection selection) async => [
      for (final item
          in await container.read(mediaIndexRepositoryProvider).load(selection))
        item.id,
    ];

    test('filters like the tabs and albums', () async {
      expect(await ids(MediaSelection.all), ['1', '2', '3']);
      expect(await ids(MediaSelection.camera), ['1']);
      expect(await ids(MediaSelection.photos), ['1', '3']);
      expect(await ids(MediaSelection.videos), ['2']);
      expect(await ids(MediaSelection.favorites), ['3']);
      expect(await ids(const MediaSelection(albumId: 'cam')), ['1', '2']);
    });

    test('sorts and limits to a date range', () async {
      const bySize = MediaSort(field: MediaSortField.size, descending: false);
      expect(await ids(const MediaSelection(sort: bySize)), ['2', '3', '1']);
      const byDuration = MediaSort(field: MediaSortField.duration);
      expect(await ids(const MediaSelection(sort: byDuration)), [
        '2',
        '1',
        '3',
      ]);
      final april = MediaSelection(
        dates: DateFilter.days(DateTime(2026, 4), DateTime(2026, 4, 30)),
      );
      expect(await ids(april), ['2']);
    });

    test('sorts by the corrected date, or the platform date', () async {
      // Item 3 was received in June but taken in January.
      await db
          .update(db.assets)
          .write(AssetsCompanion(captureAt: Value(DateTime(2026, 1, 2))));
      await (db.update(db.assets)..where((t) => t.id.isNotIn([3]))).write(
        const AssetsCompanion(captureAt: Value(null)),
      );
      await (db.update(db.assets)..where((t) => t.id.equals(3))).write(
        AssetsCompanion(takenAt: Value(DateTime(2026, 6))),
      );
      final corrected = await ids(MediaSelection.all);
      final platform = [
        for (final item in await MediaIndexRepository(
          db,
          correctedDates: false,
        ).load(MediaSelection.all))
          item.id,
      ];
      expect(corrected, ['1', '2', '3']);
      expect(platform, ['3', '1', '2']);
    });

    test('albums: counts and newest covers, without trashed items', () async {
      final repository = container.read(mediaIndexRepositoryProvider);
      var albums = await repository.albums();
      expect(albums.map((a) => (a.id, a.name, a.count, a.cover?.id)), [
        ('cam', 'Camera', 2, '1'),
        ('shots', 'Screenshots', 1, '3'),
      ]);

      await container.read(trashRepositoryProvider).trash([
        camera,
      ], retentionDays: 30);
      albums = await repository.albums();
      expect(albums.first.count, 1);
      expect(albums.first.cover?.id, '2');
      expect(await repository.count(MediaSelection.all), 2);
      expect((await repository.newest(MediaSelection.all))?.id, '2');
    });
  });
}
