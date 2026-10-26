import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/features/library/fast_scroller.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  // 600 photos, one per day going back from today: about 20 months.
  final today = DateTime.now();
  final library = [
    for (var i = 0; i < 600; i++)
      testItem(
        i,
        takenAt: DateTime(today.year, today.month, today.day - i, 12),
        sizeBytes: (600 - i) * 1024 * 1024,
      ),
  ];

  Finder thumb() => find.descendant(
    of: find.byType(FastScroller),
    matching: find.byType(AnimatedContainer),
  );

  double scrollOffset(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .pixels;

  testApp('hidden until the list scrolls, then shown', (tester) async {
    await pumpTestApp(tester, media: FakeMediaSource(items: library));
    final opacity = find.descendant(
      of: find.byType(FastScroller),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);

    // Fades out after a pause.
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);
  });

  testApp('dragging the thumb jumps and shows the month', (tester) async {
    await pumpTestApp(tester, media: FakeMediaSource(items: library));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();

    final gesture = await tester.startGesture(tester.getCenter(thumb()));
    // A finger moves in small steps.
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
    }
    expect(scrollOffset(tester), greaterThan(2000));
    // The bubble shows a month and a year, e.g. "March 2025".
    expect(find.textContaining(RegExp(r'^[A-Z][a-z]+ \d{4}$')), findsOne);

    await gesture.up();
    await tester.pump();
    expect(find.textContaining(RegExp(r'^[A-Z][a-z]+ \d{4}$')), findsNothing);
  });

  testApp('sorted by size, the bubble shows a size', (tester) async {
    await pumpTestApp(tester, media: FakeMediaSource(items: library));
    await tester.tap(find.byTooltip('Sort and filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Size'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(thumb()));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    expect(find.textContaining(RegExp(r'^\d+(\.\d)? MB$')), findsOne);
    await gesture.up();
  });

  testApp('short lists have no thumb', (tester) async {
    await pumpTestApp(
      tester,
      media: FakeMediaSource(items: library.take(10).toList()),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
    await tester.pump();
    expect(thumb(), findsNothing);
  });

  testApp('formatBytes', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('en'),
        delegates: AppLocalizations.localizationsDelegates,
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(formatBytes(context, 512), '512 B');
    expect(formatBytes(context, 2048), '2 KB');
    expect(formatBytes(context, (4.2 * 1024 * 1024).round()), '4.2 MB');
    expect(formatBytes(context, 3 * 1024 * 1024 * 1024), '3.0 GB');
  });
}
