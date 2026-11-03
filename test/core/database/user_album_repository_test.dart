import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/core/database/trash_repository.dart';
import 'package:clean_gallery/core/database/user_album_repository.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/platform/media_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late MediaIndexRepository index;
  late UserAlbumRepository albums;
  final now = DateTime(2026, 11, 1, 12);

  setUp(() async {
    db = inMemoryDatabase();
    index = MediaIndexRepository(db);
    albums = UserAlbumRepository(db);
    // Item 1 is the newest.
    await index.upsert([
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

  Future<List<String>> shown(int album) async => [
    for (final item in await index.load(MediaSelection(userAlbumId: album)))
      item.id,
  ];

  test('a new album is empty, newest album first', () async {
    final first = await albums.create(' Holidays ', now: now);
    final second = await albums.create('Family', now: now.add(Duration.zero));
    final list = await albums.watchAlbums().first;
    expect(list.map((a) => a.id), [second, first]);
    expect(list.last.name, 'Holidays');
    expect(list.last.count, 0);
    expect(list.last.cover, isNull);
  });

  test('adding counts only new items; the selection shows them', () async {
    final album = await albums.create('Holidays');
    expect(await albums.add(album, ['3', '1']), 2);
    expect(await albums.add(album, ['1', '2']), 1);
    expect(await shown(album), ['1', '2', '3']);
    final listed = (await albums.watchAlbums().first).single;
    expect(listed.count, 3);
    expect(listed.cover?.id, '1');
  });

  test('an item can be in several albums', () async {
    final a = await albums.create('A');
    final b = await albums.create('B');
    await albums.add(a, ['1', '2']);
    await albums.add(b, ['2']);
    expect(await albums.containing(['2']), {a: 1, b: 1});
    expect(await albums.containing(['1', '2']), {a: 2, b: 1});
    expect(await shown(b), ['2']);
  });

  test('trashed items are neither shown nor counted, and come back', () async {
    final album = await albums.create('A');
    await albums.add(album, ['1', '2']);
    final trash = TrashRepository(db);
    await trash.trash([testItem(1)], retentionDays: 30);
    final listed = (await albums.watchAlbums().first).single;
    expect(listed.count, 1);
    expect(listed.cover?.id, '2');
    await trash.restore(['1']);
    expect((await albums.watchAlbums().first).single.count, 2);
  });

  test('items missing from the index stay in the album', () async {
    final album = await albums.create('A');
    await albums.add(album, ['1', '2']);
    // E.g. limited access: the item leaves the index, not the device.
    await index.remove([2]);
    expect((await albums.watchAlbums().first).single.count, 1);
    expect(await albums.containing(['2']), {album: 1});
  });

  test('removing and forgetting items', () async {
    final a = await albums.create('A');
    final b = await albums.create('B');
    await albums.add(a, ['1', '2', '3']);
    await albums.add(b, ['3']);
    await albums.remove(a, ['2']);
    expect(await shown(a), ['1', '3']);
    await albums.forget(['3']);
    expect(await shown(a), ['1']);
    expect(await shown(b), isEmpty);
    // The media index is untouched.
    expect(await index.count(MediaSelection.all), 4);
  });

  test('the chosen cover, while it is in the album', () async {
    final album = await albums.create('A');
    await albums.add(album, ['1', '3']);
    await albums.setCover(album, '3');
    expect((await albums.watchAlbums().first).single.cover?.id, '3');
    await albums.remove(album, ['3']);
    expect((await albums.watchAlbums().first).single.cover?.id, '1');
    await albums.setCover(album, null);
    expect((await albums.watchAlbums().first).single.cover?.id, '1');
  });

  test('rename', () async {
    final album = await albums.create('A');
    await albums.rename(album, ' Trip ');
    expect((await albums.watchAlbums().first).single.name, 'Trip');
  });

  test('deleting keeps the media; restore brings the album back', () async {
    final album = await albums.create('A', now: now);
    await albums.add(album, ['1', '2']);
    await albums.setCover(album, '2');
    final deleted = await albums.delete(album);
    expect(deleted, isNotNull);
    expect(await albums.watchAlbums().first, isEmpty);
    expect(await db.select(db.userAlbumItems).get(), isEmpty);
    expect(await index.count(MediaSelection.all), 4);
    await albums.restore(deleted!);
    final listed = (await albums.watchAlbums().first).single;
    expect(listed.id, album);
    expect(listed.count, 2);
    expect(listed.cover?.id, '2');
    expect(await albums.delete(999), isNull);
  });

  test('album pages save their sort apart', () {
    expect(
      const MediaSelection(userAlbumId: 1),
      isNot(const MediaSelection(userAlbumId: 2)),
    );
  });
}
