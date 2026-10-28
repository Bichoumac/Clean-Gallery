import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/media/location_scan.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/geo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeMediaSource source;
  late FakePermissionService permissions;
  late ProviderContainer container;

  setUp(() {
    db = inMemoryDatabase();
    source = FakeMediaSource(
      items: [
        testItem(1, takenAt: DateTime(2026, 5, 3)),
        testItem(2, takenAt: DateTime(2026, 5, 2)),
        testItem(3, takenAt: DateTime(2026, 5)),
      ],
    );
    source.positions
      ..['1'] = (latitude: 48.85, longitude: 2.29)
      ..['3'] = (latitude: 45.76, longitude: 4.83);
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

  Future<void> syncAndScan() async {
    await container.read(mediaIndexProvider.notifier).sync();
    await container.read(locationScanProvider.notifier).run();
  }

  Future<List<LocatedItem>> located() =>
      container.read(mediaIndexRepositoryProvider).located();

  test('reads each location once and lists located items', () async {
    await syncAndScan();
    final items = await located();
    expect(items.map((i) => i.item.id), ['1', '3']);
    expect(items.first.position, (latitude: 48.85, longitude: 2.29));

    await syncAndScan();
    expect(source.locationCalls, [
      ['1', '2', '3'],
    ]);
  });

  test('reads nothing without the location permission', () async {
    permissions.locationGranted = false;
    await syncAndScan();
    expect(source.locationCalls, isEmpty);
    expect(await located(), isEmpty);

    // Granted later: every item is read.
    permissions.locationGranted = true;
    await syncAndScan();
    expect(source.locationCalls.single, ['1', '2', '3']);
  });

  test('a changed file is read again', () async {
    await syncAndScan();
    source
      ..items = [
        testItem(1, takenAt: DateTime(2026, 5, 3), sizeBytes: 99),
        ...source.items.skip(1),
      ]
      ..revisions['1'] = 2;
    source.positions.remove('1');
    await syncAndScan();
    expect(source.locationCalls.last, ['1']);
    expect((await located()).map((i) => i.item.id), ['3']);
  });

  test('a selection by area lists the items taken there', () async {
    await syncAndScan();
    final paris = await container
        .read(mediaIndexRepositoryProvider)
        .load(
          const MediaSelection(
            area: GeoArea(south: 48, west: 2, north: 49, east: 3),
          ),
        );
    expect(paris.map((i) => i.id), ['1']);
  });
}
