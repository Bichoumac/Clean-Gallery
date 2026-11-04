import 'package:clean_gallery/core/database/trash_repository.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/features/library/albums_screen.dart';
import 'package:clean_gallery/features/trash/trash_screen.dart';
import 'package:clean_gallery/features/viewer/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();
  FakeMediaSource source() => FakeMediaSource(
    items: [
      testItem(1, takenAt: now),
      testItem(2, takenAt: now.subtract(const Duration(minutes: 1))),
      testItem(3, takenAt: now.subtract(const Duration(minutes: 2))),
    ],
  );

  List<String> shownIds(WidgetTester tester) => tester
      .widgetList<MediaThumbnail>(find.byType(MediaThumbnail))
      .map((t) => t.item.id)
      .toList();

  Future<void> openTrash(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
    expect(find.byType(TrashScreen), findsOneWidget);
  }

  testApp('trash from the viewer hides the item; undo brings it back', (
    tester,
  ) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byType(MediaThumbnail).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move to trash'));
    await tester.pumpAndSettle();

    // The viewer moves on to the next photo.
    expect(find.byType(ViewerScreen), findsOneWidget);
    expect(find.text('IMG_2.jpg'), findsOneWidget);
    expect(find.text('Moved to trash'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(shownIds(tester), ['1', '2', '3']);
  });

  testApp('trashed items appear in the Trash with days left', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byType(MediaThumbnail).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move to trash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(shownIds(tester), ['2', '3']);

    await openTrash(tester);
    expect(find.text('30 days'), findsOneWidget);
  });

  testApp('restore from the Trash', (tester) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await TrashRepository(db).trash([testItem(1)], retentionDays: 30);
    await pumpTestApp(tester, media: source(), database: db);
    expect(shownIds(tester), ['2', '3']);

    await openTrash(tester);
    await tester.tap(find.byType(MediaThumbnail));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to throw away'), findsOneWidget);
  });

  testApp('delete for good after confirming', (tester) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await TrashRepository(db).trash([testItem(1)], retentionDays: 30);
    final bridge = FakePlatformBridge();
    await pumpTestApp(tester, media: source(), database: db, bridge: bridge);

    await openTrash(tester);
    await tester.tap(find.byType(MediaThumbnail));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete for good'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 1 item for good?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(bridge.deleteRequests, [
      ['1'],
    ]);
    expect(find.text('Nothing to throw away'), findsOneWidget);
  });

  testApp('declining the system prompt keeps the item', (tester) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await TrashRepository(db).trash([testItem(1)], retentionDays: 30);
    final bridge = FakePlatformBridge()..acceptRequests = false;
    await pumpTestApp(tester, media: source(), database: db, bridge: bridge);

    await openTrash(tester);
    await tester.tap(find.text('Empty trash'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing was deleted.'), findsOneWidget);
    expect(find.byType(MediaThumbnail), findsOneWidget);
  });

  testApp('expired items: offered once at launch, deleted on confirm', (
    tester,
  ) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await TrashRepository(db).trash(
      [testItem(1)],
      retentionDays: 30,
      now: now.subtract(const Duration(days: 31)),
    );
    final bridge = FakePlatformBridge();
    await pumpTestApp(tester, media: source(), database: db, bridge: bridge);

    expect(find.text('1 item has expired'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(bridge.deleteRequests, [
      ['1'],
    ]);
  });

  testApp('expired items with Media management: deleted without asking', (
    tester,
  ) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await TrashRepository(db).trash(
      [testItem(1)],
      retentionDays: 30,
      now: now.subtract(const Duration(days: 31)),
    );
    final bridge = FakePlatformBridge()..mediaManagementGranted = true;
    await pumpTestApp(tester, media: source(), database: db, bridge: bridge);

    expect(find.text('1 item has expired'), findsNothing);
    expect(bridge.deleteRequests, [
      ['1'],
    ]);
  });

  testApp('the Trash album shows its count', (tester) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await TrashRepository(db)
        .trash([testItem(1), testItem(2)], retentionDays: 30);
    await pumpTestApp(tester, media: source(), database: db);
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    final trashTile = find.ancestor(
      of: find.text('Trash'),
      matching: find.byType(InkWell),
    );
    expect(
      find.descendant(of: trashTile, matching: find.text('2 items')),
      findsOneWidget,
    );
    expect(find.byType(AlbumsScreen), findsOneWidget);
  });
}
