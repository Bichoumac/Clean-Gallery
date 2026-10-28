import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  // Newest first by id. 1, 4 and 6 are three copies; 2 and 5 two copies; 3
  // has none. 1 to 3 are in Camera, 4 to 6 in WhatsApp.
  final items = [
    for (var i = 1; i <= 6; i++)
      testItem(
        i,
        takenAt: DateTime(2026, 5, 10 - i),
        sizeBytes: switch (i) {
          1 || 4 || 6 => 100,
          2 || 5 => 200,
          _ => 300,
        },
      ),
  ];

  setUp(() async {
    db = inMemoryDatabase();
    final source = FakeMediaSource(
      items: items,
      folders: const [
        Album(id: 'cam', name: 'Camera', count: 0),
        Album(id: 'wa', name: 'WhatsApp', count: 0),
      ],
      folderItems: {'cam': items.sublist(0, 3), 'wa': items.sublist(3)},
    );
    source.hashes
      ..['1'] = 'a'
      ..['4'] = 'a'
      ..['6'] = 'a'
      ..['2'] = 'b'
      ..['5'] = 'b';
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaSourceProvider.overrideWithValue(source),
        permissionServiceProvider.overrideWithValue(FakePermissionService()),
      ],
    );
    await container.read(mediaIndexProvider.notifier).sync();
    await container.read(duplicateScanProvider.notifier).run();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<List<String>> load({
    bool descending = true,
    int? limit,
    int offset = 0,
  }) async {
    final items = await container
        .read(mediaIndexRepositoryProvider)
        .load(
          MediaSelection(
            sort: MediaSort(
              field: MediaSortField.duplicates,
              descending: descending,
            ),
          ),
          limit: limit,
          offset: offset,
        );
    return [for (final item in items) item.id];
  }

  test('largest groups first, a group together, newest first in it', () async {
    expect(await load(), ['1', '4', '6', '2', '5', '3']);
  });

  test('ascending: items without duplicates first', () async {
    expect(await load(descending: false), ['3', '2', '5', '1', '4', '6']);
  });

  test('loads in chunks like any order', () async {
    expect(await load(limit: 2), ['1', '4']);
    expect(await load(offset: 2), ['6', '2', '5', '3']);
  });

  test('a trashed copy shrinks its group', () async {
    final repository = container.read(trashRepositoryProvider);
    await repository.trash([items[0], items[3]], retentionDays: 30);
    // Group a keeps only 6: no longer a duplicate.
    // Trashed items are still loaded (screens hide them), in date order.
    expect(await load(), ['2', '5', '1', '3', '4', '6']);
  });

  test('counts the duplicates of each folder', () async {
    final counts = await container
        .read(mediaIndexRepositoryProvider)
        .duplicateCountsByFolder();
    expect(counts, {'cam': 2, 'wa': 3});
  });
}
