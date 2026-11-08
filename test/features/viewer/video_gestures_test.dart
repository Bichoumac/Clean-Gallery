import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/features/viewer/video_gestures.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import '../../helpers/fakes.dart';

/// A ready player that records what it is asked, without a platform.
class _FakePlayer extends VideoPlayerController {
  _FakePlayer() : super.networkUrl(Uri.parse('https://example.invalid/v.mp4')) {
    value = const VideoPlayerValue(
      duration: Duration(minutes: 1),
      position: Duration(seconds: 30),
      size: Size(1920, 1080),
      isInitialized: true,
    );
  }

  double speed = 1;

  @override
  Future<void> seekTo(Duration position) async =>
      value = value.copyWith(position: position);

  @override
  Future<void> setPlaybackSpeed(double speed) async => this.speed = speed;
}

const _area = Key('area');

/// The gestures over an 800 × 600 area, inside a page view of two pages
/// like the viewer's.
Future<({_FakePlayer player, FakePlatformBridge bridge, PageController pages})>
_pump(WidgetTester tester, {VoidCallback? onTap}) async {
  final player = _FakePlayer();
  final bridge = FakePlatformBridge()
    ..systemBrightness = 0.5
    ..volume = 0.5;
  final pages = PageController();
  addTearDown(pages.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [platformBridgeProvider.overrideWithValue(bridge)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PageView(
          controller: pages,
          children: [
            VideoGestures(
              controller: player,
              onTap: onTap ?? () {},
              child: const ColoredBox(key: _area, color: Colors.black),
            ),
            const ColoredBox(color: Colors.white),
          ],
        ),
      ),
    ),
  );
  return (player: player, bridge: bridge, pages: pages);
}

Future<void> _doubleTapAt(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tapAt(at);
  await tester.pump();
}

void main() {
  testWidgets('a double tap on the right jumps forward, again adds up', (
    tester,
  ) async {
    final (:player, bridge: _, pages: _) = await _pump(tester);
    await _doubleTapAt(tester, const Offset(700, 300));
    expect(player.value.position, const Duration(seconds: 40));
    expect(find.text('+10 s'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await _doubleTapAt(tester, const Offset(700, 300));
    expect(player.value.position, const Duration(seconds: 50));
    expect(find.text('+20 s'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('a double tap on the left jumps back, not before the start', (
    tester,
  ) async {
    final (:player, bridge: _, pages: _) = await _pump(tester);
    await player.seekTo(const Duration(seconds: 4));
    await _doubleTapAt(tester, const Offset(100, 300));
    expect(player.value.position, Duration.zero);
    expect(find.text('−10 s'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('a single tap still toggles the controls', (tester) async {
    var taps = 0;
    await _pump(tester, onTap: () => taps++);
    await tester.tapAt(const Offset(400, 400));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(taps, 1);
  });

  testWidgets('sliding up on the left brightens; leaving gives it back', (
    tester,
  ) async {
    final (player: _, :bridge, pages: _) = await _pump(tester);
    // 0.6 × 600 px is the full range: 180 px is half of it.
    await tester.dragFrom(const Offset(100, 450), const Offset(0, -198));
    await tester.pump();
    expect(bridge.brightness, closeTo(1.0, 0.06));
    expect(find.textContaining('Brightness'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(bridge.brightness, isNull, reason: 'back to the system');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('sliding down on the right lowers the volume', (tester) async {
    final (player: _, :bridge, pages: _) = await _pump(tester);
    await tester.dragFrom(const Offset(700, 300), const Offset(0, 108));
    await tester.pump();
    expect(bridge.volume, closeTo(0.25, 0.06));
    expect(find.textContaining('Volume'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('sliding in the top band sets the speed, not the page', (
    tester,
  ) async {
    final (:player, bridge: _, :pages) = await _pump(tester);
    await tester.dragFrom(const Offset(300, 60), const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(player.speed, 1.5);
    expect(pages.page, 0, reason: 'the band keeps the slide');

    // Lower down, a horizontal slide moves to the next page as before.
    await tester.dragFrom(const Offset(600, 400), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(pages.page, 1);
  });
}
