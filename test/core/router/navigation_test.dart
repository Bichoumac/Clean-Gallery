import 'package:clean_gallery/core/router/compact_nav_bar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testApp('shows five icon-only tabs, Photos first', (tester) async {
    await pumpTestApp(tester);
    for (final label in ['Photos', 'Videos', 'Albums', 'Stats', 'Settings']) {
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
    expect(find.text('Photos'), findsOneWidget); // Page title.
  });

  testApp('tapping Stats shows the reclaimable space', (tester) async {
    await pumpTestApp(tester);
    await tester.tap(find.byTooltip('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Space you could free'), findsOneWidget);
    expect(find.text('Duplicates'), findsOneWidget);
  });

  testApp('tapping Photos again returns to Photos', (tester) async {
    await pumpTestApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.byTooltip('Photos'));
    await tester.pumpAndSettle();
    expect(find.text('Photos'), findsOneWidget);
  });

  testApp('tab touch targets are at least 48 dp', (tester) async {
    await pumpTestApp(tester);
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
