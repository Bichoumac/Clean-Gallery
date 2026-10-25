import 'package:clean_gallery/app.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/compact_nav_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          permissionServiceProvider.overrideWithValue(FakePermissionService()),
          platformBridgeProvider.overrideWithValue(FakePlatformBridge()),
          initialOnboardingCompletedProvider.overrideWithValue(true),
        ],
        child: const CleanGalleryApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows five icon-only tabs, Photos first', (tester) async {
    await pumpShell(tester);
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

  testWidgets('tapping Stats shows the reclaimable space', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Space you could free'), findsOneWidget);
    expect(find.text('Duplicates'), findsOneWidget);
  });

  testWidgets('tapping Photos again returns to Photos', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.byTooltip('Photos'));
    await tester.pumpAndSettle();
    expect(find.text('Photos'), findsOneWidget);
  });

  testWidgets('tab touch targets are at least 48 dp', (tester) async {
    await pumpShell(tester);
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
