import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

/// The accessibility rules of the brief, checked by Flutter's guidelines on
/// the app's screens, in light and dark themes: touch targets of at least
/// 48 dp, a label on everything tappable, and text contrast.
void main() {
  Future<void> check(WidgetTester tester, String screen) async {
    for (final (guideline, rule) in [
      (androidTapTargetGuideline, 'tap targets'),
      (labeledTapTargetGuideline, 'labels'),
      (textContrastGuideline, 'contrast'),
    ]) {
      final evaluation = await guideline.evaluate(tester);
      expect(
        evaluation.passed,
        isTrue,
        reason: '$screen, $rule:\n${evaluation.reason}',
      );
    }
  }

  /// Runs [body] with the semantics tree on, as a screen reader would.
  Future<void> withSemantics(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await body();
    } finally {
      semantics.dispose();
    }
  }

  Future<void> start(
    WidgetTester tester, {
    required bool dark,
    bool onboardingCompleted = true,
  }) async {
    if (dark) {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    }
    await pumpTestApp(
      tester,
      onboardingCompleted: onboardingCompleted,
      media: FakeMediaSource(
        items: [
          for (var i = 1; i <= 6; i++) testItem(i),
          testItem(7, duration: const Duration(seconds: 12)),
        ],
      ),
    );
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    final theme = dark ? ' (dark)' : '';

    testApp('the tabs meet the guidelines$theme', (tester) async {
      await withSemantics(tester, () async {
        await start(tester, dark: dark);
        await check(tester, 'Camera');
        for (final tab in ['Videos', 'Albums', 'Stats', 'Settings']) {
          await tap(tester, find.byTooltip(tab));
          await check(tester, tab);
        }
      });
    });

    testApp('the pages under the tabs meet the guidelines$theme', (
      tester,
    ) async {
      await withSemantics(tester, () async {
        await start(tester, dark: dark);
        await tap(tester, find.byTooltip('Albums'));
        await tap(tester, find.text('Trash'));
        await check(tester, 'Trash');
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tap(tester, find.byTooltip('Search'));
        await check(tester, 'Search');
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tap(tester, find.byTooltip('Settings'));
        await tester.scrollUntilVisible(
          find.text('Rituals'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tap(tester, find.text('Rituals'));
        await check(tester, 'Rituals');
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('About Clean Gallery'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tap(tester, find.text('About Clean Gallery'));
        await check(tester, 'About');
      });
    });

    testApp('the viewer meets the guidelines$theme', (tester) async {
      await withSemantics(tester, () async {
        await start(tester, dark: dark);
        await tap(tester, find.byType(MediaThumbnail).first);
        await check(tester, 'Viewer');
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tap(tester, find.byTooltip('Videos'));
        await tap(tester, find.byType(MediaThumbnail).first);
        await check(tester, 'Video viewer');
      });
    });

    testApp('the onboarding meets the guidelines$theme', (tester) async {
      await withSemantics(tester, () async {
        await start(tester, dark: dark, onboardingCompleted: false);
        await check(tester, 'Onboarding');
      });
    });
  }
}
