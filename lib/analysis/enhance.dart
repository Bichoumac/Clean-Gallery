import 'dart:math' as math;
import 'dart:typed_data';

import 'package:clean_gallery/domain/photo_edit.dart';

/// Share of the darkest and of the lightest pixels let go to pure black and
/// pure white: a few specular highlights or deep shadows do not hold the
/// stretch back.
const enhanceClip = 0.005;

/// Histogram of the luminance (Rec. 709, 0 to 255) of RGBA pixels
/// ([rgba], 4 bytes per pixel), reading one pixel in [step].
List<int> luminanceHistogram(Uint8List rgba, {int step = 4}) {
  final histogram = List<int>.filled(256, 0);
  for (var i = 0; i + 3 < rgba.length; i += 4 * step) {
    final y = 0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2];
    histogram[y.round().clamp(0, 255)]++;
  }
  return histogram;
}

/// The value below which [share] of the pixels of [histogram] fall.
int _percentile(List<int> histogram, double share) {
  final total = histogram.fold(0, (sum, n) => sum + n);
  final target = total * share;
  var seen = 0;
  for (var value = 0; value < 256; value++) {
    seen += histogram[value];
    if (seen > target) return value;
  }
  return 255;
}

/// Adjustments that stretch the photo of [histogram] to the full range of
/// light ("auto levels"): its darkest [enhanceClip] becomes black, its
/// lightest white. Expressed with the editor's own sliders (brightness and
/// contrast; a little saturation, which a flat photo loses), so the user
/// can refine them. A histogram algorithm, no machine learning.
///
/// Leaves [base]'s other adjustments as they are. A photo already using
/// the full range gets nothing but the saturation.
Adjustments autoEnhance(
  List<int> histogram, {
  Adjustments base = const Adjustments(),
}) {
  final low = _percentile(histogram, enhanceClip);
  final high = math.max(_percentile(histogram, 1 - enhanceClip), low + 1);
  // Wanted: x → (x - low) × 255 / (high - low). The editor applies
  // brightness (x + 64 b), then contrast around 127.5 (× c).
  final gain = (255 / (high - low)).clamp(1.0, 2.0);
  final contrast = gain - 1;
  final offset = 127.5 - 127.5 / gain - low;
  final brightness = (offset / 64).clamp(-1.0, 1.0);
  return base.copyWith(
    contrast: _round(contrast),
    brightness: _round(brightness),
    saturation: _round(math.max(base.saturation, 0.1)),
  );
}

/// [value] to the slider's step (1 %).
double _round(double value) => (value * 100).round() / 100;
