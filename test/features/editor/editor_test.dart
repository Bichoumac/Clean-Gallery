import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/features/editor/editor_screen.dart';
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
      testItem(
        2,
        takenAt: now.subtract(const Duration(minutes: 1)),
        duration: const Duration(seconds: 5),
      ),
    ],
  );

  Future<void> openEditor(WidgetTester tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byType(MediaThumbnail).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsOneWidget);
  }

  int quarterTurns(WidgetTester tester) => tester
      .widget<RotatedBox>(
        find.descendant(
          of: find.byType(EditorScreen),
          matching: find.byType(RotatedBox),
        ),
      )
      .quarterTurns;

  testApp('the viewer opens the editor on photos only', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byTooltip('Videos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnail).first);
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget);
    expect(find.byTooltip('Edit'), findsNothing);
  });

  testApp('rotate turns the photo; close without changes asks nothing', (
    tester,
  ) async {
    await openEditor(tester);
    expect(quarterTurns(tester), 0);
    await tester.tap(find.text('Rotate'));
    await tester.pumpAndSettle();
    expect(quarterTurns(tester), 1);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(quarterTurns(tester), 0);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsNothing);
    expect(find.byType(ViewerScreen), findsOneWidget);
  });

  testApp('an adjustment colors the preview; closing asks first', (
    tester,
  ) async {
    await openEditor(tester);
    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();
    expect(find.byType(ColorFiltered), findsNothing);
    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(find.text('Brightness •'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsNothing);
  });

  testApp('a fixed shape crops the preview to that shape', (tester) async {
    await openEditor(tester);
    await tester.tap(find.text('1:1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();
    final clip = tester.getSize(
      find
          .descendant(
            of: find.byType(EditorScreen),
            matching: find.byType(ClipRect),
          )
          .first,
    );
    expect(clip.width, closeTo(clip.height, 0.5));
  });

  testApp('dragging a corner of the crop shrinks it', (tester) async {
    await openEditor(tester);
    final area = find.bySemanticsLabel(RegExp('Crop area'));
    final box = tester.getRect(area);
    await tester.dragFrom(
      box.bottomRight - const Offset(4, 4),
      const Offset(-60, -40),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reset'), findsOneWidget);
    // Something changed: Reset is enabled.
    final reset = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Reset'),
    );
    expect(reset.onPressed, isNotNull);
  });
}
