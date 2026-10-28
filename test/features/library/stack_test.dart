import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/features/viewer/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();

  // Photos 1 and 4 are on their own; 2 and 3, identical copies taken one
  // after the other, stack (2, a favorite, is the best).
  FakeMediaSource source() {
    final media = FakeMediaSource(
      items: [
        testItem(1, takenAt: now, sizeBytes: 500),
        testItem(
          2,
          takenAt: now.subtract(const Duration(minutes: 1)),
          sizeBytes: 2000,
          isFavorite: true,
        ),
        testItem(
          3,
          takenAt: now.subtract(const Duration(minutes: 2)),
          sizeBytes: 2000,
        ),
        testItem(4, takenAt: now.subtract(const Duration(minutes: 3))),
      ],
    );
    media.hashes
      ..['2'] = 'same'
      ..['3'] = 'same';
    return media;
  }

  List<String> shownIds(WidgetTester tester) => tester
      .widgetList<MediaThumbnail>(find.byType(MediaThumbnail))
      .map((t) => t.item.id)
      .toList();

  Finder stackOf(int size) =>
      find.byWidgetPredicate((w) => w is MediaThumbnail && w.stackSize == size);

  testApp('consecutive duplicates fold into one thumbnail', (tester) async {
    await pumpTestApp(tester, media: source());
    expect(shownIds(tester), ['1', '2', '4']);
    expect(stackOf(2), findsOneWidget);
    expect(
      find.descendant(of: stackOf(2), matching: find.text('2')),
      findsOneWidget,
    );
  });

  testApp('a tap unfolds the stack; its fold button folds it again', (
    tester,
  ) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(stackOf(2));
    await tester.pumpAndSettle();
    expect(shownIds(tester), ['1', '2', '3', '4']);
    expect(find.byType(ViewerScreen), findsNothing);

    // Unfolded, a photo of the stack opens the viewer at its own place.
    await tester.tap(find.byType(MediaThumbnail).at(2));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Fold the stack'));
    await tester.pumpAndSettle();
    expect(shownIds(tester), ['1', '2', '4']);
  });

  testApp('selecting a folded stack selects all its items', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.longPress(stackOf(2));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byType(MediaThumbnail).first);
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);

    await tester.tap(stackOf(2));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
  });
}
