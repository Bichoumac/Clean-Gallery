import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final day = DateTime(2025, 3, 10, 12);

  // Three photos, a day apart.
  FakeMediaSource source() => FakeMediaSource(
    items: [
      for (var i = 1; i <= 3; i++)
        testItem(
          i,
          takenAt: day.add(Duration(days: i)),
          sizeBytes: 1000 * i,
        ),
    ],
  );

  Future<void> openAllPhotos(
    WidgetTester tester, {
    AppDatabase? database,
  }) async {
    await pumpTestApp(tester, media: source(), database: database);
    await tester.tap(find.byTooltip('Stats'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sort mode'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All photos'));
    await tester.pumpAndSettle();
  }

  final card = find.byKey(const ValueKey('swipe-card'));

  Future<Set<String>> trashed(WidgetTester tester) => tester
      .runAsync(
        () => ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        ).read(trashRepositoryProvider).trashedIds(),
      )
      .then((ids) => ids!);

  testApp('swipe left trashes, right keeps; undo brings it back', (
    tester,
  ) async {
    await openAllPhotos(tester);
    expect(find.text('0 / 3'), findsOneWidget);

    await tester.drag(card, const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(await trashed(tester), {'1'});

    await tester.fling(card, const Offset(150, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 3'), findsOneWidget);
    expect(await trashed(tester), isEmpty);
  });

  testApp('a short drag springs back', (tester) async {
    await openAllPhotos(tester);
    await tester.drag(card, const Offset(-40, 0));
    await tester.pumpAndSettle();
    expect(find.text('0 / 3'), findsOneWidget);
  });

  testApp('buttons sort too, then a summary', (tester) async {
    await openAllPhotos(tester);
    await tester.tap(find.byTooltip('Move to trash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Keep'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Keep as a favorite'));
    await tester.pumpAndSettle();

    expect(find.text('All sorted!'), findsOneWidget);
    expect(find.text('1 moved to the trash'), findsOneWidget);
    expect(find.text('1 kept'), findsOneWidget);
    expect(find.text('1 kept as a favorite'), findsOneWidget);
    // Undo still works from the summary.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testApp('leaving and coming back resumes the session', (tester) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await openAllPhotos(tester, database: db);
    await tester.tap(find.byTooltip('Keep'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close; you can resume later'));
    await tester.pumpAndSettle();
    expect(find.text('1 sorted · resume'), findsOneWidget);

    await tester.tap(find.text('All photos'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
  });
}
