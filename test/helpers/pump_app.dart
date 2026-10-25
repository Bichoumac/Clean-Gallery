import 'package:clean_gallery/app.dart';
import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Pumps the whole app with fake services and an in-memory database.
///
/// Pass fakes to inspect or configure them; defaults are an empty library,
/// granted permissions and completed onboarding. Pass [database] to prepare
/// rows before the app starts; the caller then closes it.
Future<void> pumpTestApp(
  WidgetTester tester, {
  bool onboardingCompleted = true,
  FakeMediaSource? media,
  FakePermissionService? permissions,
  FakePlatformBridge? bridge,
  AppSettings settings = const AppSettings(),
  AppDatabase? database,
}) async {
  // A phone-sized screen (1080 × 2400 px at 3×), portrait.
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = database ?? inMemoryDatabase();
  if (database == null) addTearDown(db.close);
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
        initialAppSettingsProvider.overrideWithValue(settings),
      ],
      child: const CleanGalleryApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// A widget test of the whole app.
///
/// After [body], unmounts the app and lets one frame pass: Drift closes
/// cancelled stream queries on a zero-duration timer, which must run before
/// the test ends, or Flutter reports a pending timer.
void testApp(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      // Also after a failure, or the pending timer hangs the whole run.
      await tester.pumpWidget(const SizedBox());
      // A real (fake-clock) delay: a zero-length pump does not fire timers
      // created during that frame.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    }
  });
}
