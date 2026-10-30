import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/features/scan/scan_screen.dart';
import 'package:clean_gallery/features/viewer/viewer_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();

  /// Lets image work run outside the fake clock until [done].
  Future<void> waitUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 50 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  testApp('a photo is scanned into a new flat page', (tester) async {
    final media = FakeMediaSource(items: [testItem(1, takenAt: now)]);
    final bridge = FakePlatformBridge()
      ..onSaveEdit = (photo) {
        media.items = [testItem(9, takenAt: photo.takenAt), ...media.items];
        return '9';
      };
    await pumpTestApp(tester, media: media, bridge: bridge);
    await tester.tap(find.byType(MediaThumbnail).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Scan a document'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ScanScreen), findsOneWidget);

    // The blank test photo has no page: the corners are to place.
    final hint = find.text("Drag the four corners onto the page's corners.");
    await waitUntil(tester, () => hint.evaluate().isNotEmpty);
    expect(hint, findsOneWidget);
    final area = tester.getRect(find.bySemanticsLabel(RegExp('Page corners')));
    // The top left corner is 8 % in.
    await tester.dragFrom(
      area.topLeft + Offset(area.width * 0.08, area.height * 0.08),
      const Offset(-10, -10),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await waitUntil(
      tester,
      () => find.text('Black & white').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('Black & white'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await waitUntil(tester, () => find.byType(ScanScreen).evaluate().isEmpty);
    await tester.pumpAndSettle();
    expect(bridge.savedEdits.single.$1, '1');
    expect(find.text('Scan saved'), findsOneWidget);
    expect(find.byType(ViewerScreen), findsOneWidget);
    expect(find.text('IMG_9.jpg'), findsOneWidget);
  });

  testApp('Back from the page returns to the corners', (tester) async {
    await pumpTestApp(
      tester,
      media: FakeMediaSource(items: [testItem(1, takenAt: now)]),
    );
    await tester.tap(find.byType(MediaThumbnail).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Scan a document'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await waitUntil(tester, () => find.text('Next').evaluate().isNotEmpty);
    await waitUntil(
      tester,
      () => find.bySemanticsLabel(RegExp('Page corners')).evaluate().isNotEmpty,
    );
    await tester.tap(find.text('Next'));
    await waitUntil(tester, () => find.text('Color').evaluate().isNotEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Page corners')), findsOneWidget);
  });
}
