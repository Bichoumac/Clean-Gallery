import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/media/selection_bar.dart';
import 'package:clean_gallery/core/router/compact_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();
  // Twelve photos of today: three rows of four.
  FakeMediaSource source() => FakeMediaSource(
    items: [
      for (var i = 0; i < 12; i++)
        testItem(i, takenAt: now.subtract(Duration(minutes: i))),
    ],
  );

  Finder thumb(int index) => find.byType(MediaThumbnail).at(index);

  List<String> shownIds(WidgetTester tester) => tester
      .widgetList<MediaThumbnail>(find.byType(MediaThumbnail))
      .map((t) => t.item.id)
      .toList();

  testApp('long press selects; the selection bar replaces the nav bar', (
    tester,
  ) async {
    await pumpTestApp(tester, media: source());
    await tester.longPress(thumb(0));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionBar), findsOneWidget);
    expect(find.byType(CompactNavBar), findsNothing);
    expect(find.text('1 selected'), findsOneWidget);

    // A tap adds another item instead of opening the viewer.
    await tester.tap(thumb(2));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel selection'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionBar), findsNothing);
    expect(find.byType(CompactNavBar), findsOneWidget);
  });

  testApp('long press then drag selects the whole range', (tester) async {
    await pumpTestApp(tester, media: source());
    final start = tester.getCenter(thumb(0));
    final end = tester.getCenter(thumb(6)); // Second row, third column.
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 600)); // Long press.
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(start, end, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('7 selected'), findsOneWidget);
  });

  testApp('trash the selection, then undo', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.longPress(thumb(0));
    await tester.pumpAndSettle();
    await tester.tap(thumb(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move to trash'));
    await tester.pumpAndSettle();

    expect(shownIds(tester).take(2), ['2', '3']);
    expect(find.byType(SelectionBar), findsNothing);
    expect(find.text('2 items moved to trash'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(shownIds(tester).take(2), ['0', '1']);
  });

  testApp('favorite the selection through the system request', (tester) async {
    final bridge = FakePlatformBridge();
    await pumpTestApp(tester, media: source(), bridge: bridge);
    await tester.longPress(thumb(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pumpAndSettle();
    final (ids, favorite) = bridge.favoriteRequests.single;
    expect(ids, ['0']);
    expect(favorite, isTrue);
  });

  testApp('share the selection without location by default', (tester) async {
    final bridge = FakePlatformBridge();
    await pumpTestApp(tester, media: source(), bridge: bridge);
    await tester.longPress(thumb(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    expect(find.text('Share 1 item'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pumpAndSettle();
    final (ids, removeLocation) = bridge.shareRequests.single;
    expect(ids, ['0']);
    expect(removeLocation, isTrue);
  });

  testApp('back leaves selection mode', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.longPress(thumb(0));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(SelectionBar), findsNothing);
  });
}
