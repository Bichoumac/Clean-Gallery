import 'package:clean_gallery/analysis/analysis_version.dart';
import 'package:clean_gallery/analysis/similarity.dart';
import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../analysis/photo_set.dart';
import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeMediaSource source;
  late ProviderContainer container;

  // 1 is a photo; 2 is the same photo a little brighter, saved a month
  // later; 3 is an unrelated photo; 4 has no readable thumbnail; 5 is a
  // video. Sizes differ, so no file is read for exact duplicates.
  final beach = PhotoSet.scene(1);
  final original = testItem(1, sizeBytes: 900, takenAt: DateTime(2026, 5));
  final edited = testItem(2, sizeBytes: 800, takenAt: DateTime(2026, 6));
  final other = testItem(3, sizeBytes: 700, takenAt: DateTime(2026, 4));
  final unreadable = testItem(4, sizeBytes: 600, takenAt: DateTime(2026, 3));
  final video = testItem(
    5,
    sizeBytes: 500,
    takenAt: DateTime(2026, 2),
    duration: const Duration(seconds: 3),
  );

  setUp(() {
    db = inMemoryDatabase();
    source =
        FakeMediaSource(items: [edited, original, other, unreadable, video])
          ..grayImages.addAll({
            '1': PhotoSet.thumbnail(beach),
            '2': PhotoSet.thumbnail(PhotoSet.brightened(beach, 20)),
            '3': PhotoSet.thumbnail(PhotoSet.scene(2)),
          });
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

  /// Groups as `kind: ids`, best first, e.g. `similar: 1,2`.
  Future<List<String>> groups([
    MediaSelection base = MediaSelection.all,
  ]) async => [
    for (final group
        in await container
            .read(mediaIndexRepositoryProvider)
            .duplicateGroups(base))
      '${group.kind.name}: ${group.items.map((i) => i.id).join(',')}',
  ];

  test('groups similar photos, best first', () async {
    await syncAndScan();
    expect(await groups(), ['similar: 1,2']);
  });

  test('reads thumbnails of photos only, once', () async {
    await syncAndScan();
    expect(
      source.grayCalls.expand((ids) => ids),
      unorderedEquals(['1', '2', '3', '4']),
    );
    source.grayCalls.clear();
    await container.read(duplicateScanProvider.notifier).run();
    expect(source.grayCalls, isEmpty, reason: 'hashes are kept');
    final rows = {
      for (final row in await db.select(db.assets).get()) row.id: row,
    };
    expect(rows[4]!.pHash, isNull, reason: 'no thumbnail, no hash');
    expect(rows[4]!.analysisVersion, analysisVersion, reason: 'not retried');
    expect(rows[5]!.analysisVersion, 0, reason: 'videos are not compared');
  });

  test('"Not duplicates" splits the group for good', () async {
    await syncAndScan();
    final group =
        (await container
                .read(mediaIndexRepositoryProvider)
                .duplicateGroups(MediaSelection.all))
            .single;
    await container.read(duplicateScanProvider.notifier).ignore(group);
    expect(await groups(), isEmpty, reason: 'gone at once');
    await container.read(duplicateScanProvider.notifier).run();
    expect(await groups(), isEmpty, reason: 'not grouped again');
    await container.read(duplicateScanProvider.notifier).reanalyze();
    expect(await groups(), isEmpty, reason: 'kept by Analyze again');
  });

  test('a changed file is hashed again', () async {
    await syncAndScan();
    source
      ..revisions['2'] = 2
      ..items = [
        edited.copyWith(modifiedAt: DateTime(2026, 7)),
        original,
        other,
        unreadable,
        video,
      ]
      ..grayImages['2'] = PhotoSet.thumbnail(PhotoSet.scene(3));
    source.grayCalls.clear();
    await syncAndScan();
    expect(source.grayCalls.expand((ids) => ids), ['2']);
    expect(await groups(), isEmpty);
  });

  test('new thresholds regroup without reading thumbnails', () async {
    await syncAndScan();
    source.grayCalls.clear();
    final settings = container.read(appSettingsControllerProvider.notifier);
    await settings.setSimilaritySensitivity(SimilaritySensitivity.custom);
    await settings.setCustomThresholds(
      const SimilarityThresholds(strict: 0, loose: 0, window: Duration.zero),
    );
    await container.read(duplicateScanProvider.notifier).run();
    expect(await groups(), isEmpty);
    expect(source.grayCalls, isEmpty);
    await settings.setSimilaritySensitivity(SimilaritySensitivity.medium);
    await container.read(duplicateScanProvider.notifier).run();
    expect(await groups(), hasLength(1));
  });

  test('exact copies stay certain duplicates, not similar photos', () async {
    final copy = testItem(6, sizeBytes: 900, takenAt: DateTime(2026, 5));
    source
      ..items = [original, copy]
      ..hashes['1'] = 'same'
      ..hashes['6'] = 'same'
      ..grayImages['6'] = PhotoSet.thumbnail(beach);
    await syncAndScan();
    expect(await groups(), ['exact: 1,6']);
  });

  test('similar groups are filtered by the displayed folder', () async {
    source
      ..folders = const [
        Album(id: 'cam', name: 'Camera', count: 0),
        Album(id: 'wa', name: 'WhatsApp', count: 0),
      ]
      ..folderItems = {
        'cam': [original, other],
        'wa': [edited],
      };
    await syncAndScan();
    expect(await groups(const MediaSelection(albumId: 'cam')), isEmpty);
    expect(await groups(), hasLength(1));
  });
}
