import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/features/viewer/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final items = [
    testItem(1, takenAt: DateTime(2026, 10, 25, 12)),
    testItem(2, takenAt: DateTime(2026, 10, 25, 11)),
    testItem(3, takenAt: DateTime(2026, 10, 25, 10)),
  ];

  Future<void> openViewerAt(WidgetTester tester, int index) async {
    await pumpTestApp(tester, media: FakeMediaSource(items: items));
    await tester.tap(find.byType(MediaThumbnail).at(index));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget);
  }

  testApp('swiping left shows the next photo', (tester) async {
    await openViewerAt(tester, 0);
    expect(find.text('IMG_1.jpg'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('IMG_2.jpg'), findsOneWidget);
  });

  testApp('swiping right shows the previous photo', (tester) async {
    await openViewerAt(tester, 2);
    expect(find.text('IMG_3.jpg'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('IMG_2.jpg'), findsOneWidget);
  });

  testApp('a slow drag also changes page', (tester) async {
    await openViewerAt(tester, 0);
    await tester.drag(find.byType(PageView), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.text('IMG_2.jpg'), findsOneWidget);
  });

  testApp('zoomed in: one finger pans instead of changing page', (
    tester,
  ) async {
    await openViewerAt(tester, 0);
    final center = tester.getCenter(find.byType(PageView));

    // Pinch out with two fingers moving together in small steps, like a
    // real pinch (a big first step of one finger would be a swipe).
    final a = await tester.startGesture(center - const Offset(30, 0));
    final b = await tester.startGesture(center + const Offset(30, 0));
    for (var i = 0; i < 25; i++) {
      await a.moveBy(const Offset(-4, 0));
      await b.moveBy(const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.text('IMG_1.jpg'), findsOneWidget);

    // Double tap back to fit: swiping works again.
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.text('IMG_2.jpg'), findsOneWidget);
  });

  testApp('a pinch whose first finger slides first still zooms', (
    tester,
  ) async {
    await openViewerAt(tester, 0);
    final center = tester.getCenter(find.byType(PageView));

    // On a phone the first finger often slides a little before the second
    // one lands, then both move fast.
    final a = await tester.startGesture(center - const Offset(30, 0));
    await a.moveBy(const Offset(-12, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final b = await tester.startGesture(center + const Offset(30, 0));
    for (var i = 0; i < 6; i++) {
      await a.moveBy(const Offset(-20, 0));
      await b.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    expect(find.text('IMG_1.jpg'), findsOneWidget);
    // Zoomed: a one-finger drag pans instead of changing page.
    await tester.drag(find.byType(PageView), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.text('IMG_1.jpg'), findsOneWidget);
  });

  testApp('the top bar only covers the top of the screen', (tester) async {
    await openViewerAt(tester, 0);
    final topBar = find.ancestor(
      of: find.text('IMG_1.jpg'),
      matching: find.byType(Positioned),
    );
    final screen = tester.getSize(find.byType(PageView));
    expect(tester.getSize(topBar).height, lessThan(screen.height / 4));
  });
}
