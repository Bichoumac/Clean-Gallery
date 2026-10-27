import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();
  final old = now.subtract(const Duration(days: 60));
  const megabyte = 1024 * 1024;

  FakeMediaSource source() => FakeMediaSource(
    items: [
      testItem(1, takenAt: old, relativePath: 'DCIM/Screenshots/'),
      testItem(2, takenAt: old, relativePath: 'DCIM/Screenshots/'),
      // Recent: not offered yet.
      testItem(3, takenAt: now, relativePath: 'DCIM/Screenshots/'),
      testItem(4, takenAt: old),
      testItem(
        5,
        takenAt: old,
        duration: const Duration(minutes: 3),
        sizeBytes: 300 * megabyte,
      ),
      testItem(
        6,
        takenAt: old,
        duration: const Duration(seconds: 10),
        sizeBytes: 5 * megabyte,
      ),
    ],
  );

  List<String> shownIds(WidgetTester tester) => tester
      .widgetList<MediaThumbnail>(find.byType(MediaThumbnail))
      .map((t) => t.item.id)
      .toList();

  Future<void> openStats(WidgetTester tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byTooltip('Stats'));
    await tester.pumpAndSettle();
    // The second card is below the first screen.
    await tester.scrollUntilVisible(
      find.text('Large videos'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testApp('Stats counts old screenshots and large videos', (tester) async {
    await openStats(tester);
    expect(find.text('Old screenshots'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Large videos'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
  });

  testApp('old screenshots: select all, then move to trash', (tester) async {
    await openStats(tester);
    await tester.tap(find.text('Old screenshots'));
    await tester.pumpAndSettle();
    expect(find.text('Taken more than 30 days ago'), findsOneWidget);
    expect(find.textContaining('2 items ·'), findsOneWidget);

    await tester.longPress(find.byType(MediaThumbnail).first);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.byTooltip('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.byTooltip('Select all'), findsNothing);

    await tester.tap(find.byTooltip('Move to trash'));
    await tester.pumpAndSettle();
    expect(find.text('No old screenshots'), findsOneWidget);
  });

  testApp('large videos: the rule and the size threshold', (tester) async {
    await openStats(tester);
    await tester.tap(find.text('Large videos'));
    await tester.pumpAndSettle();
    expect(find.text('100 MB or more, largest first'), findsOneWidget);
    expect(shownIds(tester), ['5']);
  });
}
