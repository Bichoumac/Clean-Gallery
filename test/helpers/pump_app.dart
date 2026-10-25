import 'package:clean_gallery/app.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Pumps the whole app with fake services and an in-memory database.
///
/// Pass fakes to inspect or configure them; defaults are an empty library,
/// granted permissions and completed onboarding.
Future<void> pumpTestApp(
  WidgetTester tester, {
  bool onboardingCompleted = true,
  FakeMediaSource? media,
  FakePermissionService? permissions,
  FakePlatformBridge? bridge,
}) async {
  // A phone-sized screen (1080 × 2400 px at 3×), portrait.
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = inMemoryDatabase();
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaSourceProvider.overrideWithValue(media ?? FakeMediaSource()),
        permissionServiceProvider.overrideWithValue(
          permissions ?? FakePermissionService(),
        ),
        platformBridgeProvider.overrideWithValue(
          bridge ?? FakePlatformBridge(),
        ),
        initialOnboardingCompletedProvider.overrideWithValue(
          onboardingCompleted,
        ),
      ],
      child: const CleanGalleryApp(),
    ),
  );
  await tester.pumpAndSettle();
}
