import 'dart:typed_data';

import 'package:clean_gallery/analysis/color_matrix.dart';
import 'package:clean_gallery/analysis/document.dart';
import 'package:clean_gallery/domain/gray_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A 100 × 80 dark table with a light quadrilateral sheet whose corners
  /// are [corners] (pixels), filled by testing which side of each edge a
  /// pixel is on.
  GrayImage sheet(List<Point> corners) {
    const w = 100;
    const h = 80;
    final pixels = Uint8List(w * h);
    bool inside(double x, double y) {
      for (var k = 0; k < 4; k++) {
        final (ax, ay) = corners[k];
        final (bx, by) = corners[(k + 1) % 4];
        if ((bx - ax) * (y - ay) - (by - ay) * (x - ax) < 0) return false;
      }
      return true;
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        pixels[y * w + x] = inside(x + 0.5, y + 0.5) ? 230 : 40;
      }
    }
    return GrayImage(width: w, height: h, pixels: pixels);
  }

  test('finds the corners of a tilted sheet', () {
    const corners = <Point>[(20, 10), (85, 18), (78, 72), (12, 62)];
    final found = detectDocument(sheet(corners))!;
    for (var k = 0; k < 4; k++) {
      expect(found[k].$1 * 100, closeTo(corners[k].$1, 3));
      expect(found[k].$2 * 80, closeTo(corners[k].$2, 3));
    }
  });

  test('nothing when no sheet stands out', () {
    final flat = GrayImage(
      width: 50,
      height: 50,
      pixels: Uint8List(2500)..fillRange(0, 2500, 128),
    );
    expect(detectDocument(flat), isNull);
    // A light speck is too small to be a page.
    expect(
      detectDocument(sheet(const [(10, 10), (14, 10), (14, 14), (10, 14)])),
      isNull,
    );
  });

  test('the homography takes each corner where asked', () {
    const from = <Point>[(20, 10), (85, 18), (78, 72), (12, 62)];
    const to = <Point>[(0, 0), (300, 0), (300, 400), (0, 400)];
    final h = homography(from, to);
    for (var k = 0; k < 4; k++) {
      final (x, y) = applyHomography(h, from[k]);
      expect(x, closeTo(to[k].$1, 1e-6));
      expect(y, closeTo(to[k].$2, 1e-6));
    }
  });

  test('a page photographed at an angle gets its longer sides', () {
    final (w, h) = pageSize(const [(0, 0), (100, 0), (90, 200), (10, 200)]);
    expect(w, 100);
    expect(h, closeTo(200.25, 0.01));
  });

  test('Otsu splits two clusters between them', () {
    final histogram = List<int>.filled(256, 0)
      ..[40] = 500
      ..[220] = 500;
    final t = otsuThreshold(histogram);
    expect(t, greaterThanOrEqualTo(40));
    expect(t, lessThan(220));
  });

  test('black and white turns paper white and ink black', () {
    // Mostly paper at 200, ink at 50.
    final histogram = List<int>.filled(256, 0)
      ..[200] = 900
      ..[50] = 100;
    final m = documentMatrix(DocumentMode.blackWhite, histogram);
    expect(applyMatrix(m, 200, 200, 200).$1, 255);
    expect(applyMatrix(m, 50, 50, 50).$1, 0);
    // Gray: the same value in every channel.
    final (r, g, b) = applyMatrix(
      documentMatrix(DocumentMode.gray, histogram),
      200,
      120,
      60,
    );
    expect(r, closeTo(g, 1e-9));
    expect(g, closeTo(b, 1e-9));
  });

  test('a small RGBA image becomes gray at most maxSide wide', () {
    final rgba = Uint8List(400 * 300 * 4)..fillRange(0, 400 * 300 * 4, 255);
    final gray = grayFromRgba(rgba, 400, 300, maxSide: 100);
    expect(gray.width, 100);
    expect(gray.height, 75);
    expect(gray.pixels.first, 255);
  });
}
