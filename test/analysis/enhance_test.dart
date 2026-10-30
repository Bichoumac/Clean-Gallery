import 'dart:typed_data';

import 'package:clean_gallery/analysis/color_matrix.dart';
import 'package:clean_gallery/analysis/enhance.dart';
import 'package:clean_gallery/domain/photo_edit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A histogram with as many pixels at each value from [low] to [high].
  List<int> flat(int low, int high) => [
    for (var v = 0; v < 256; v++)
      if (v >= low && v <= high) 100 else 0,
  ];

  double after(Adjustments a, double value) =>
      applyMatrix(adjustmentMatrix(a), value, value, value).$1;

  test('a dull photo is stretched to the full range', () {
    final enhanced = autoEnhance(flat(70, 200));
    expect(enhanced.contrast, greaterThan(0));
    // Its darkest values become near black, its lightest near white.
    expect(after(enhanced, 71), lessThan(12));
    expect(after(enhanced, 199), greaterThan(243));
  });

  test("the stretch stops at the contrast slider's maximum (× 2)", () {
    final enhanced = autoEnhance(flat(100, 140));
    expect(enhanced.contrast, 1);
  });

  test('a photo already using the full range only gets saturation', () {
    final enhanced = autoEnhance(flat(0, 255));
    // The clipped 0.5 % at each end leaves a stretch too small to see.
    expect(enhanced.contrast, lessThanOrEqualTo(0.01));
    expect(enhanced.brightness.abs(), lessThanOrEqualTo(0.01));
    expect(enhanced.saturation, 0.1);
  });

  test('a few extreme pixels do not hold the stretch back', () {
    final histogram = flat(80, 160)
      ..[0] = 2
      ..[255] = 2;
    expect(autoEnhance(histogram).contrast, greaterThan(0.5));
  });

  test('other adjustments are kept', () {
    final enhanced = autoEnhance(
      flat(70, 200),
      base: const Adjustments(warmth: 0.3, vignette: 0.2),
    );
    expect(enhanced.warmth, 0.3);
    expect(enhanced.vignette, 0.2);
  });

  test('the histogram counts the luminance of RGBA pixels', () {
    final pixels = Uint8List.fromList([
      255, 255, 255, 255, // White.
      0, 0, 0, 255, // Black.
    ]);
    final histogram = luminanceHistogram(pixels, step: 1);
    expect(histogram[255], 1);
    expect(histogram[0], 1);
  });
}
