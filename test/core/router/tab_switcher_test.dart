import 'package:clean_gallery/core/router/tab_switcher.dart';
import 'package:clean_gallery/core/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tab counting its taps, to check it keeps its state.
class _Tab extends StatefulWidget {
  const _Tab(this.name);

  final String name;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => taps++),
    child: ColoredBox(
      color: Colors.white,
      child: Center(child: Text('${widget.name} $taps')),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  int index, {
  bool reducedMotion = false,
}) => tester.pumpWidget(
  MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 600),
      disableAnimations: reducedMotion,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: TabSwitcher(
        index: index,
        children: const [_Tab('A'), _Tab('B'), _Tab('C')],
      ),
    ),
  ),
);

double _left(WidgetTester tester, String name) => tester
    .getRect(
      find.ancestor(of: find.textContaining(name), matching: find.byType(_Tab)),
    )
    .left;

void main() {
  testWidgets('the new tab slides in from the side of its button', (
    tester,
  ) async {
    await _pump(tester, 0);
    await _pump(tester, 2);
    await tester.pump(AppMotion.tab ~/ 2);

    // C comes from the right, A leaves to the left.
    expect(_left(tester, 'C'), inExclusiveRange(0, 800));
    expect(_left(tester, 'A'), inExclusiveRange(-800, 0));
    expect(find.textContaining('B'), findsNothing);

    await tester.pumpAndSettle();
    expect(_left(tester, 'C'), 0);
    expect(find.textContaining('A'), findsNothing);

    // Back to A: it comes from the left this time.
    await _pump(tester, 0);
    await tester.pump(AppMotion.tab ~/ 2);
    expect(_left(tester, 'A'), inExclusiveRange(-800, 0));
    expect(_left(tester, 'C'), inExclusiveRange(0, 800));
  });

  testWidgets('tabs keep their state and only the current one takes taps', (
    tester,
  ) async {
    await _pump(tester, 0);
    await tester.tap(find.text('A 0'));
    await tester.pump();
    expect(find.text('A 1'), findsOneWidget);

    await _pump(tester, 1);
    // During the slide, a tap does not reach the leaving tab.
    await tester.pump(AppMotion.tab ~/ 2);
    await tester.tapAt(tester.getCenter(find.text('A 1')));
    await tester.pumpAndSettle();

    await _pump(tester, 0);
    await tester.pumpAndSettle();
    expect(find.text('A 1'), findsOneWidget);
  });

  testWidgets('with reduced motion the tab changes at once', (tester) async {
    await _pump(tester, 0, reducedMotion: true);
    await _pump(tester, 1, reducedMotion: true);
    await tester.pump();
    expect(_left(tester, 'B'), 0);
    expect(find.textContaining('A'), findsNothing);
  });
}
