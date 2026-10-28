import 'package:clean_gallery/analysis/color_matrix.dart';
import 'package:clean_gallery/domain/photo_edit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  (double, double, double) apply(ColorMatrix m, double r, double g, double b) =>
      applyMatrix(m, r, g, b);

  test('neutral adjustments change nothing', () {
    final m = adjustmentMatrix(const Adjustments());
    for (var i = 0; i < 20; i++) {
      expect(m[i], closeTo(identityMatrix[i], 1e-12));
    }
  });

  test('composing with identity keeps a matrix', () {
    final m = contrastMatrix(0.4);
    expect(compose(identityMatrix, m), m);
    expect(compose(m, identityMatrix), m);
  });

  test('composition applies the first matrix first', () {
    final first = brightnessMatrix(0.5); // +32
    final second = exposureMatrix(1); // ×2
    final (r, _, _) = apply(compose(first, second), 50, 50, 50);
    expect(r, closeTo((50 + 32) * 2, 1e-9));
  });

  test('brightness and exposure lighten, negative values darken', () {
    expect(apply(brightnessMatrix(1), 100, 100, 100).$1, 164);
    expect(apply(brightnessMatrix(-1), 100, 100, 100).$1, 36);
    expect(apply(exposureMatrix(1), 100, 100, 100).$1, 200);
    expect(apply(exposureMatrix(-1), 100, 100, 100).$1, 50);
  });

  test('channels are clamped to 0–255', () {
    expect(apply(exposureMatrix(1), 200, 10, 10).$1, 255);
    expect(apply(brightnessMatrix(-1), 10, 10, 10).$1, 0);
  });

  test('contrast spreads values around mid-gray, which stays', () {
    expect(
      apply(contrastMatrix(1), 127.5, 127.5, 127.5).$1,
      closeTo(127.5, 1e-9),
    );
    expect(apply(contrastMatrix(1), 200, 200, 200).$1, closeTo(255, 1e-9));
    final (low, _, _) = apply(contrastMatrix(-1), 200, 200, 200);
    expect(low, lessThan(200));
    expect(low, greaterThan(127.5));
  });

  test('saturation -1 makes gray of the same luminance', () {
    final (r, g, b) = apply(saturationMatrix(-1), 200, 100, 50);
    expect(r, closeTo(g, 1e-9));
    expect(g, closeTo(b, 1e-9));
    expect(r, closeTo(0.2126 * 200 + 0.7152 * 100 + 0.0722 * 50, 1e-9));
  });

  test('saturation leaves grays alone and spreads colors', () {
    final (gr, gg, gb) = apply(saturationMatrix(1), 90, 90, 90);
    for (final channel in [gr, gg, gb]) {
      expect(channel, closeTo(90, 1e-9));
    }
    final (r, _, b) = apply(saturationMatrix(0.5), 200, 100, 50);
    expect(r, greaterThan(200));
    expect(b, lessThan(50));
  });

  test('warmth adds red and removes blue, coolness the other way', () {
    final (wr, _, wb) = apply(warmthMatrix(1), 100, 100, 100);
    expect(wr, greaterThan(100));
    expect(wb, lessThan(100));
    final (cr, _, cb) = apply(warmthMatrix(-1), 100, 100, 100);
    expect(cr, lessThan(100));
    expect(cb, greaterThan(100));
  });

  test('alpha is never changed', () {
    final m = adjustmentMatrix(
      const Adjustments(
        brightness: 0.3,
        contrast: -0.2,
        saturation: 0.5,
        exposure: 0.4,
        warmth: -0.6,
      ),
    );
    expect(m.sublist(15), [0, 0, 0, 1, 0]);
  });
}
