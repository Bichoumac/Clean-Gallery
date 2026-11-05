import 'package:clean_gallery/core/brand/petal_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gaugePetals', () {
    test('nothing to free lights no petal', () {
      expect(gaugePetals(reclaimable: 0, used: 1000), 0);
      expect(gaugePetals(reclaimable: 0, used: 0), 0);
    });

    test('a tiny share still lights one petal', () {
      expect(gaugePetals(reclaimable: 1, used: 1000000), 1);
    });

    test('half lights four petals', () {
      expect(gaugePetals(reclaimable: 500, used: 1000), 4);
    });

    test('rounds to the nearest petal', () {
      // 3/8 = 37.5 %, 4/8 = 50 %: the middle is 43.75 %.
      expect(gaugePetals(reclaimable: 430, used: 1000), 3);
      expect(gaugePetals(reclaimable: 440, used: 1000), 4);
    });

    test('all of it, or more with the trash, fills the gauge', () {
      expect(gaugePetals(reclaimable: 1000, used: 1000), 8);
      expect(gaugePetals(reclaimable: 3000, used: 1000), 8);
      expect(gaugePetals(reclaimable: 10, used: 0), 8);
    });
  });

  group('PetalMark.kept', () {
    test('has eight petals, only the 45° one lit', () {
      final mark = PetalMark.kept(
        size: 100,
        unlit: Colors.grey,
        lit: Colors.yellow,
      );
      expect(mark.colors, hasLength(petalCount));
      for (final (i, color) in mark.colors.indexed) {
        expect(color, i == 1 ? Colors.yellow : Colors.grey, reason: 'petal $i');
      }
    });
  });

  testWidgets('the mark paints only the given colors at their places', (
    tester,
  ) async {
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: PetalMark.kept(
            size: 100,
            unlit: const Color(0xFF0000FF),
            lit: const Color(0xFFFF0000),
          ),
        ),
      ),
    );
    expect(find.byType(PetalMark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the gauge fills without throwing, and settles', (tester) async {
    Widget gauge(int lit) => Directionality(
      textDirection: TextDirection.ltr,
      child: PetalGauge(lit: lit),
    );
    await tester.pumpWidget(gauge(0));
    await tester.pumpWidget(gauge(8));
    await tester.pumpAndSettle();
    expect(find.byType(PetalGauge), findsOneWidget);
  });

  testWidgets('with reduced motion, a rosace is complete at once', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: BloomingMark(
          size: 100,
          colors: List.filled(petalCount, Colors.black),
        ),
      ),
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
