import 'dart:math' as math;

import 'package:clean_gallery/domain/photo_edit.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const crop = CropRect(left: 0.1, top: 0.2, right: 0.5, bottom: 0.6);

  Matcher closeToRect(CropRect expected) => predicate<CropRect>(
    (r) =>
        (r.left - expected.left).abs() < 1e-9 &&
        (r.top - expected.top).abs() < 1e-9 &&
        (r.right - expected.right).abs() < 1e-9 &&
        (r.bottom - expected.bottom).abs() < 1e-9,
    'close to $expected',
  );

  group('CropRect', () {
    test('turns with the photo, back after four quarter turns', () {
      expect(
        crop.rotatedClockwise(),
        closeToRect(
          const CropRect(left: 0.4, top: 0.1, right: 0.8, bottom: 0.5),
        ),
      );
      var turned = crop;
      for (var i = 0; i < 4; i++) {
        turned = turned.rotatedClockwise();
      }
      expect(turned, closeToRect(crop));
    });

    test('is mirrored with the photo', () {
      expect(
        crop.flipped(),
        closeToRect(
          const CropRect(left: 0.5, top: 0.2, right: 0.9, bottom: 0.6),
        ),
      );
      expect(crop.flipped().flipped(), closeToRect(crop));
    });

    test('moves without leaving the photo', () {
      expect(
        crop.moved(0.8, -0.5),
        closeToRect(const CropRect(left: 0.6, bottom: 0.4)),
      );
    });
  });

  group('fitRatio', () {
    test('a square in a 4:3 photo takes the full height', () {
      final square = fitRatio(CropRect.full, 1, 4 / 3);
      expect(square.height, closeTo(1, 1e-9));
      expect(square.width, closeTo(0.75, 1e-9));
      expect(square.left, closeTo(0.125, 1e-9));
    });

    test('16:9 in a 4:3 photo takes the full width, centered', () {
      final wide = fitRatio(CropRect.full, 16 / 9, 4 / 3);
      expect(wide.width, closeTo(1, 1e-9));
      expect(wide.height, closeTo(0.75, 1e-9));
      expect(wide.top, closeTo(0.125, 1e-9));
    });

    test('stays inside the photo around an off-center crop', () {
      const corner = CropRect(left: 0.8, top: 0.8);
      final square = fitRatio(corner, 1, 4 / 3);
      expect(square.right, closeTo(1, 1e-9));
      expect(square.bottom, closeTo(1, 1e-9));
    });
  });

  group('dragCorner', () {
    test('free: the corner follows the finger, the opposite one stays', () {
      final r = dragCorner(CropRect.full, CropHandle.bottomRight, -0.3, -0.2);
      expect(r, closeToRect(const CropRect(right: 0.7, bottom: 0.8)));
    });

    test('top left corner', () {
      final r = dragCorner(CropRect.full, CropHandle.topLeft, 0.2, 0.1);
      expect(r, closeToRect(const CropRect(left: 0.2, top: 0.1)));
    });

    test('never smaller than the minimum, never outside', () {
      final small = dragCorner(CropRect.full, CropHandle.bottomRight, -2, -2);
      expect(small.width, closeTo(minCropSide, 1e-9));
      expect(small.height, closeTo(minCropSide, 1e-9));
      final big = dragCorner(crop, CropHandle.bottomRight, 5, 5);
      expect(big.right, 1);
      expect(big.bottom, 1);
    });

    test('a fixed ratio keeps its shape', () {
      // Square in a 2:1 photo: a height of 0.8 is a width of 0.4.
      final r = dragCorner(
        const CropRect(right: 0.5),
        CropHandle.bottomRight,
        -0.1,
        0,
        pixelRatio: 1,
        photoRatio: 2,
      );
      expect(r.width, closeTo(0.4, 1e-9));
      expect(r.height, closeTo(0.8, 1e-9));
    });
  });

  group('PhotoEdit', () {
    test('a new edit changes nothing', () {
      expect(const PhotoEdit().isIdentity, isTrue);
      expect(const PhotoEdit().rotated().isIdentity, isFalse);
      expect(const PhotoEdit().mirrored().mirrored().isIdentity, isTrue);
      expect(
        const PhotoEdit(adjustments: Adjustments(warmth: 0.2)).isIdentity,
        isFalse,
      );
    });

    test('four quarter turns come back to the start', () {
      var edit = const PhotoEdit(crop: crop);
      for (var i = 0; i < 4; i++) {
        edit = edit.rotated();
      }
      expect(edit.quarterTurns, 0);
      expect(edit.crop, closeToRect(crop));
    });

    test('the ratio of a turned photo is inverted', () {
      expect(const PhotoEdit().orientedRatio(4000, 3000), closeTo(4 / 3, 1e-9));
      expect(
        const PhotoEdit().rotated().orientedRatio(4000, 3000),
        closeTo(3 / 4, 1e-9),
      );
    });

    test('the drawing turns and mirrors with the photo', () {
      const line = Stroke(
        points: [(0.1, 0.2), (0.3, 0.4)],
        color: 0xFFFFFFFF,
        width: 0.01,
      );
      final edit = const PhotoEdit(strokes: [line]).rotated();
      expect(edit.strokes.single.points, [(0.8, 0.1), (0.6, 0.3)]);
      expect(edit.strokes.single.width, 0.01);
      expect(
        const PhotoEdit(strokes: [line]).mirrored().strokes.single.points.first,
        (0.9, 0.2),
      );
      var turned = const PhotoEdit(strokes: [line]);
      for (var i = 0; i < 4; i++) {
        turned = turned.rotated();
      }
      for (final (i, (x, y)) in turned.strokes.single.points.indexed) {
        expect(x, closeTo(line.points[i].$1, 1e-9));
        expect(y, closeTo(line.points[i].$2, 1e-9));
      }
      expect(const PhotoEdit(strokes: [line]).isIdentity, isFalse);
    });

    test('straightening enlarges the photo enough to fill its frame', () {
      expect(straightenScale(0, 4 / 3), 1);
      // A frame w × h turned by a fits in the photo enlarged by s when
      // w cos a + h sin a <= s w and w sin a + h cos a <= s h.
      for (final degrees in [1.0, 10.0, -25.0, 45.0]) {
        for (final ratio in [4 / 3, 3 / 4, 1.0, 16 / 9]) {
          final s = straightenScale(degrees, ratio);
          final a = degrees.abs() * 3.141592653589793 / 180;
          const h = 1.0;
          final w = ratio;
          expect(w * _cos(a) + h * _sin(a), lessThanOrEqualTo(s * w + 1e-9));
          expect(w * _sin(a) + h * _cos(a), lessThanOrEqualTo(s * h + 1e-9));
        }
      }
    });

    test('mirroring reverses the straightening; texts follow the photo', () {
      const text = TextItem(text: 'Hi', x: 0.2, y: 0.3);
      const edit = PhotoEdit(angle: 5, texts: [text]);
      expect(edit.mirrored().angle, -5);
      expect(edit.mirrored().texts.single.x, closeTo(0.8, 1e-9));
      final turned = edit.rotated().texts.single;
      expect((turned.x, turned.y), (0.7, 0.2));
      expect(edit.isIdentity, isFalse);
    });

    test('each adjustment reads and writes its own value', () {
      var adjustments = const Adjustments();
      for (final (i, a) in Adjustment.values.indexed) {
        adjustments = a.set(adjustments, i / 10);
      }
      for (final (i, a) in Adjustment.values.indexed) {
        expect(a.of(adjustments), i / 10);
      }
    });
  });
}

double _cos(double a) => math.cos(a);

double _sin(double a) => math.sin(a);
