import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/trash_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late TrashRepository trash;
  final now = DateTime(2026, 10, 25, 12);

  setUp(() {
    db = inMemoryDatabase();
    trash = TrashRepository(db);
  });
  tearDown(() => db.close());

  test('trashed items are listed newest first with their expiry', () async {
    await trash.trash([testItem(1)], retentionDays: 30, now: now);
    await trash.trash(
      [testItem(2)],
      retentionDays: 30,
      now: now.add(const Duration(hours: 1)),
    );
    final items = await trash.watchItems().first;
    expect(items.map((e) => e.item.id), ['2', '1']);
    expect(items.last.expiresAt, now.add(const Duration(days: 30)));
    expect(items.last.item.fileName, 'IMG_1.jpg');
  });

  test('watchTrashedIds follows trash and restore', () async {
    expect(await trash.watchTrashedIds().first, isEmpty);
    await trash.trash([testItem(1), testItem(2)], retentionDays: 30, now: now);
    expect(await trash.watchTrashedIds().first, {'1', '2'});
    await trash.restore(['1']);
    expect(await trash.watchTrashedIds().first, {'2'});
  });

  test('expired returns only items past their retention', () async {
    await trash.trash([testItem(1)], retentionDays: 1, now: now);
    await trash.trash([testItem(2)], retentionDays: 30, now: now);
    final expired = await trash.expired(now.add(const Duration(days: 2)));
    expect(expired.map((e) => e.item.id), ['1']);
  });

  test('forget removes the trash entry and the asset row', () async {
    await trash.trash([testItem(1)], retentionDays: 30, now: now);
    await trash.forget(['1']);
    expect(await trash.watchTrashedIds().first, isEmpty);
    expect(await db.select(db.assets).get(), isEmpty);
  });

  test('trashing twice keeps one entry', () async {
    await trash.trash([testItem(1)], retentionDays: 30, now: now);
    await trash.trash([testItem(1)], retentionDays: 30, now: now);
    expect(await trash.watchItems().first, hasLength(1));
  });

  test('days left are rounded up and never negative', () async {
    await trash.trash([testItem(1)], retentionDays: 3, now: now);
    final entry = (await trash.watchItems().first).single;
    expect(entry.daysLeft(now), 3);
    expect(entry.daysLeft(now.add(const Duration(days: 2, hours: 1))), 1);
    expect(entry.daysLeft(now.add(const Duration(days: 4))), 0);
    expect(entry.isExpired(now.add(const Duration(days: 3))), isTrue);
  });
}
