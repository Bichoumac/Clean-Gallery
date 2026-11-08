import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/features/viewer/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  group('pull down', pullDownTests);

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

  testApp('the actions stay put while the system bars hide with them', (
    tester,
  ) async {
    tester.view
      ..padding = const FakeViewPadding(top: 72, bottom: 144)
      ..viewPadding = const FakeViewPadding(top: 72, bottom: 144);
    addTearDown(tester.view.reset);
    await openViewerAt(tester, 0);
    final share = find.byIcon(Icons.share_rounded);
    final before = tester.getRect(share);

    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pump(const Duration(milliseconds: 400));
    // Immersive mode: the navigation and status bars leave.
    tester.view
      ..padding = FakeViewPadding.zero
      ..viewPadding = FakeViewPadding.zero;
    await tester.pump();
    expect(tester.getRect(share), before);
    await tester.pumpAndSettle();
    expect(tester.getRect(share), before);
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

void pullDownTests() {
  final items = [
    testItem(1, takenAt: DateTime(2026, 10, 25, 12)),
    testItem(2, takenAt: DateTime(2026, 10, 25, 11)),
  ];

  Future<void> open(WidgetTester tester) async {
    await pumpTestApp(tester, media: FakeMediaSource(items: items));
    await tester.tap(find.byType(MediaThumbnail).first);
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget);
  }

  /// Offset of the pages from their place.
  double pulled(WidgetTester tester) =>
      tester.getTopLeft(find.byType(PageView)).dy;

  testApp('a photo pulled a little springs back', (tester) async {
    await open(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(pulled(tester), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget);
    expect(pulled(tester), moreOrLessEquals(0, epsilon: 0.5));
  });

  testApp('a photo pulled far returns to the grid', (tester) async {
    await open(tester);
    final height = tester.getSize(find.byType(PageView)).height;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(Offset(0, height * 0.05));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsNothing);
  });

  testApp('a flick down returns to the grid', (tester) async {
    await open(tester);
    await tester.fling(find.byType(PageView), const Offset(0, 120), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsNothing);
  });

  testApp('pulling up does nothing', (tester) async {
    await open(tester);
    await tester.drag(find.byType(PageView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget);
    expect(pulled(tester), 0);
  });

  testApp('a zoomed photo pans: pulling down does not close the viewer', (
    tester,
  ) async {
    await open(tester);
    final center = tester.getCenter(find.byType(PageView));
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

    await tester.fling(find.byType(PageView), const Offset(0, 400), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget);
    expect(pulled(tester), 0);
  });

  testApp('pulling the info panel closes the panel, not the viewer', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byTooltip('Details'));
    await tester.pumpAndSettle();
    final panel = find.byType(BottomSheet);
    expect(panel, findsOneWidget);

    await tester.fling(panel, const Offset(0, 300), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(ViewerScreen), findsOneWidget);
  });
}
