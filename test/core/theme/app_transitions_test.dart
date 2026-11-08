import 'package:clean_gallery/core/theme/app_motion.dart';
import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:clean_gallery/core/theme/app_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _home = Key('home');
const _tile = Key('tile');
const _page = Key('page');

/// A home page with a small tile at (100, 200) that opens a second page,
/// marking itself as its origin when [markOrigin] is true.
Future<void> _pumpHome(
  WidgetTester tester, {
  bool markOrigin = false,
  bool reducedMotion = false,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(800, 600),
        disableAnimations: reducedMotion,
      ),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          key: _home,
          body: Stack(
            children: [
              Positioned(
                left: 100,
                top: 200,
                width: 160,
                height: 120,
                child: Builder(
                  builder: (context) => GestureDetector(
                    key: _tile,
                    onTap: () {
                      if (markOrigin) TransitionOrigin.mark(context);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(key: _page),
                        ),
                      );
                    },
                    child: const ColoredBox(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _backGesture(
  WidgetTester tester,
  String method, [
  double progress = 0,
]) async {
  final message = const StandardMethodCodec().encodeMethodCall(
    MethodCall(
      method,
      method == 'startBackGesture' || method == 'updateBackGestureProgress'
          ? <String, dynamic>{
              'touchOffset': <double>[5, 300],
              'progress': progress,
              'swipeEdge': 0,
            }
          : null,
    ),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (_) {},
  );
  await tester.pump();
}

void main() {
  // A mark left by a test must not leak into the next one.
  setUp(TransitionOrigin.take);

  testWidgets('a page slides in from the right while the one below recedes', (
    tester,
  ) async {
    await _pumpHome(tester);
    await tester.tap(find.byKey(_tile));
    await tester.pump();
    await tester.pump(AppMotion.page ~/ 2);

    final page = tester.getRect(find.byKey(_page));
    expect(page.left, greaterThan(0));
    expect(page.left, lessThan(800));
    expect(page.top, 0);
    final home = tester.getRect(find.byKey(_home));
    expect(home.width, lessThan(800), reason: 'the page below shrinks');

    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(_page)),
      Offset.zero & const Size(800, 600),
    );
  });

  testWidgets('a page opened from a tile grows out of it and back into it', (
    tester,
  ) async {
    await _pumpHome(tester, markOrigin: true);
    await tester.tap(find.byKey(_tile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // At the start the page is about the size of the tile, where it is.
    final start = tester.getRect(find.byKey(_page));
    expect(start.left, closeTo(100, 8));
    expect(start.top, closeTo(200, 8));
    expect(start.width, closeTo(160, 16));

    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(_page)),
      Offset.zero & const Size(800, 600),
    );

    // Closing shrinks it back toward the tile.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(AppMotion.pageBack * 0.9);
    final closing = tester.getRect(find.byKey(_page));
    expect(closing.width, lessThan(400));
    expect(closing.center.dx, closeTo(180, 60));
    await tester.pumpAndSettle();
    expect(find.byKey(_page), findsNothing);
  });

  testWidgets('a mark nobody used does not reach a later page', (tester) async {
    await _pumpHome(tester);
    final tile = tester.element(find.byKey(_tile));
    TransitionOrigin.mark(tile);
    // Longer than a mark lasts, in real time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    await tester.tap(find.byKey(_tile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getRect(find.byKey(_page)).height, 600, reason: 'slides');
  });

  testWidgets('with reduced motion the page is there at once', (tester) async {
    await _pumpHome(tester, markOrigin: true, reducedMotion: true);
    await tester.tap(find.byKey(_tile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester.getRect(find.byKey(_page)),
      Offset.zero & const Size(800, 600),
    );
    expect(tester.getRect(find.byKey(_home)).width, 800);
  });

  testWidgets('the back gesture moves the page with the finger', (
    tester,
  ) async {
    await _pumpHome(tester);
    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();

    await _backGesture(tester, 'startBackGesture');
    await _backGesture(tester, 'updateBackGestureProgress', 0.5);
    expect(tester.getRect(find.byKey(_page)).left, closeTo(400, 1));

    // Released early: the page comes back.
    await _backGesture(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_page)).left, 0);

    // Released after a swipe: the page leaves.
    await _backGesture(tester, 'startBackGesture');
    await _backGesture(tester, 'updateBackGestureProgress', 0.6);
    await _backGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.byKey(_page), findsNothing);
    expect(tester.getRect(find.byKey(_home)).width, 800);
  });
}
