import 'package:clean_gallery/app.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/compact_nav_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakePermissionService permissions;
  late FakePlatformBridge bridge;

  setUp(() {
    permissions = FakePermissionService();
    bridge = FakePlatformBridge();
  });

  Future<void> pumpApp(WidgetTester tester, {required bool completed}) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          permissionServiceProvider.overrideWithValue(permissions),
          platformBridgeProvider.overrideWithValue(bridge),
          initialOnboardingCompletedProvider.overrideWithValue(completed),
        ],
        child: const CleanGalleryApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first launch shows the privacy promise', (tester) async {
    await pumpApp(tester, completed: false);
    expect(find.text('Your photos never leave your device.'), findsOneWidget);
  });

  testWidgets('full flow: grant access, then land on the Photos tab', (
    tester,
  ) async {
    await pumpApp(tester, completed: false);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow access'));
    await tester.pumpAndSettle();
    expect(permissions.mediaRequests, 1);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow media management'));
    await tester.pumpAndSettle();
    expect(bridge.mediaManagementOpened, 1);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(CompactNavBar), findsOneWidget);
  });

  testWidgets('skip goes straight to the main shell', (tester) async {
    await pumpApp(tester, completed: false);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(CompactNavBar), findsOneWidget);
    expect(permissions.mediaRequests, 0);
  });

  testWidgets('returning users skip onboarding', (tester) async {
    await pumpApp(tester, completed: true);
    expect(find.byType(CompactNavBar), findsOneWidget);
    expect(find.byTooltip('Photos'), findsOneWidget);
    expect(find.byTooltip('Stats'), findsOneWidget);
  });
}
