import 'package:clean_gallery/core/router/compact_nav_bar.dart';
import 'package:clean_gallery/features/library/media_timeline_view.dart';
import 'package:clean_gallery/features/settings/settings_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testApp('shows five icon-only tabs, Camera first', (tester) async {
    await pumpTestApp(tester);
    for (final label in ['Camera', 'Videos', 'Albums', 'Stats', 'Settings']) {
      expect(find.byTooltip(label), findsOneWidget, reason: label);
    }
    // Labels are not displayed as text in the bar.
    expect(
      find.descendant(
        of: find.byType(CompactNavBar),
        matching: find.text('Videos'),
      ),
      findsNothing,
    );
    expect(find.text('Camera'), findsOneWidget); // Page title.
  });

  testApp('tapping Stats shows the reclaimable space', (tester) async {
    await pumpTestApp(tester);
    await tester.tap(find.byTooltip('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Space you could free'), findsOneWidget);
    expect(find.text('Identical copies'), findsOneWidget);
    expect(find.text('Bursts'), findsOneWidget);
    expect(find.text('Similar photos'), findsOneWidget);
  });

  testApp('tapping Camera again returns to Camera', (tester) async {
    await pumpTestApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.byTooltip('Camera'));
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);
  });

  testApp('tab touch targets are at least 48 dp', (tester) async {
    await pumpTestApp(tester);
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  // go_router gave pages without any transition (2026-11-08).
  testApp('an album opens with a transition, growing out of its tile', (
    tester,
  ) async {
    await pumpTestApp(tester);
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    final tile = tester.getRect(find.text('Favorites').first);
    await tester.tap(find.text('Favorites').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final page = tester.getRect(find.byType(MediaTimelineView).last);
    expect(page.width, lessThan(300), reason: 'still opening');
    expect(page.left, lessThan(tile.right));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(MediaTimelineView).last).width, 360);
  });

  testApp('a page under a tab slides in', (tester) async {
    await pumpTestApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    final settings = find.byType(SettingsScreen);
    await tester.scrollUntilVisible(
      find.text('Rituals'),
      300,
      scrollable: find
          .descendant(of: settings, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rituals'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // The page below recedes while the new one comes in.
    expect(tester.getRect(settings).width, lessThan(360));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing, reason: 'covered');
  });
}
