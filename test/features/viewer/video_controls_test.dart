import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:clean_gallery/features/viewer/video_page.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

void main() {
  VideoPlayerController fakeController() {
    return VideoPlayerController.networkUrl(
        Uri.parse('https://example.invalid/video.mp4'),
      )
      ..value = const VideoPlayerValue(
        duration: Duration(minutes: 1),
        position: Duration(seconds: 10),
        size: Size(1920, 1080),
        isInitialized: true,
      );
  }

  Future<void> pumpControls(
    WidgetTester tester,
    Size physicalSize, {
    double bottomInset = 0,
  }) async {
    tester.view
      ..physicalSize = physicalSize
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Same nesting as in VideoPage.
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              IgnorePointer(
                ignoring: false,
                child: AnimatedOpacity(
                  opacity: 1,
                  duration: Duration.zero,
                  child: VideoControls(
                    controller: fakeController(),
                    bottomInset: bottomInset,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  for (final (name, size) in [
    ('portrait', const Size(1080, 2400)),
    ('landscape', const Size(2400, 1080)),
  ]) {
    testWidgets('progress bar sits at the bottom in $name', (tester) async {
      await pumpControls(tester, size);
      final screen = tester.getSize(find.byType(Scaffold));
      final slider = tester.getRect(find.byType(Slider));
      expect(slider.center.dy, greaterThan(screen.height * 0.8));
      expect(
        tester.getCenter(find.byType(IconButton).first).dy,
        closeTo(screen.height / 2, 60),
      );
    });
  }

  // The slider was under the viewer's action bar with a 3-button
  // navigation bar (2026-11-08).
  testWidgets('the progress bar stays above the action bar and system bar', (
    tester,
  ) async {
    // 48 dp of system navigation bar, at 3×.
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    tester.view.padding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    await pumpControls(tester, const Size(1080, 2400), bottomInset: 64);
    final screen = tester.getSize(find.byType(Scaffold));
    final slider = tester.getRect(find.byType(Slider));
    // The action bar takes 48 + 64 dp at the bottom; 16 dp of room above.
    expect(slider.bottom, lessThanOrEqualTo(screen.height - 48 - 64 - 16));
  });
}
