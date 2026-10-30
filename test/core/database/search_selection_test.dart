import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/platform/media_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late MediaIndexRepository repository;

  setUp(() async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    repository = MediaIndexRepository(db, screen: (width: 1080, height: 2340));
    final items = [
      testItem(1, isFavorite: true).copyWith(fileName: 'Holiday_beach.jpg'),
      testItem(2).copyWith(fileName: 'holiday_city.jpg'),
      testItem(
        3,
        duration: const Duration(seconds: 5),
        isFavorite: true,
      ).copyWith(fileName: 'HOLIDAY.mp4'),
      testItem(4, isFavorite: true).copyWith(fileName: '100%_sure.jpg'),
      testItem(5).copyWith(fileName: '100x_zoom.jpg'),
    ];
    await repository.upsert([
      for (final item in items)
        IndexedMedia(
          item: item,
          albumId: item.relativePath,
          albumName: 'Camera',
          revision: 1,
        ),
    ]);
  });

  Future<Set<String>> ids(MediaSelection selection) async => {
    for (final item in await repository.load(selection)) item.id,
  };

  test('a part of the file name, ignoring case', () async {
    expect(await ids(const MediaSelection(nameContains: 'holiday')), {
      '1',
      '2',
      '3',
    });
    expect(await ids(const MediaSelection(nameContains: '  CITY ')), {'2'});
  });

  test('an empty name matches everything', () async {
    expect(await ids(const MediaSelection(nameContains: '')), hasLength(5));
  });

  test('% and _ are taken literally', () async {
    expect(await ids(const MediaSelection(nameContains: '100%')), {'4'});
    expect(await ids(const MediaSelection(nameContains: '0_')), <String>{});
  });

  test('favorites combine with the type and the name', () async {
    expect(await ids(const MediaSelection(favoritesOnly: true)), {
      '1',
      '3',
      '4',
    });
    expect(
      await ids(
        const MediaSelection(
          filter: MediaFilter.photos,
          favoritesOnly: true,
          nameContains: 'holiday',
        ),
      ),
      {'1'},
    );
    expect(
      await ids(
        const MediaSelection(filter: MediaFilter.videos, favoritesOnly: true),
      ),
      {'3'},
    );
  });
}
