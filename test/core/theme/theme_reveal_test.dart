import 'package:clean_gallery/core/theme/theme_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {bool reducedMotion = false}) async {
  var dark = false;
  if (reducedMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.pumpWidget(
    StatefulBuilder(
      builder: (context, setState) => MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        themeAnimationStyle: AnimationStyle.noAnimation,
        builder: (context, child) => ThemeReveal(child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => ThemeReveal.change(
                  context,
                  () => setState(() => dark = !dark),
                ),
                child: const Text('Switch'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the new theme is revealed by a growing circle', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Switch'));
    await tester.pump();

    // The old screen lies over the new theme, then goes away.
    expect(find.byType(RawImage), findsOneWidget);
    await tester.pump(ThemeReveal.duration ~/ 2);
    expect(
      Theme.of(tester.element(find.text('Switch'))).brightness,
      Brightness.dark,
    );
    expect(find.byType(RawImage), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsNothing);
  });

  testWidgets('with reduced motion the theme changes at once', (tester) async {
    await _pump(tester, reducedMotion: true);
    await tester.tap(find.text('Switch'));
    await tester.pump();
    expect(find.byType(RawImage), findsNothing);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Switch'))).brightness,
      Brightness.dark,
    );
  });
}
