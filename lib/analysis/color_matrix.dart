import 'dart:math' as math;

import 'package:clean_gallery/domain/photo_edit.dart';

/// A color transform: 4 rows (red, green, blue, alpha) of 5 values (the
/// weights of red, green, blue and alpha, then an offset from 0 to 255),
/// row after row.
///
/// The layout of Flutter's `ColorFilter.matrix` and Android's
/// `ColorMatrix`, so the editor's preview and the saved photo use the same
/// numbers.
typedef ColorMatrix = List<double>;

/// The transform that changes nothing.
const ColorMatrix identityMatrix = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

/// Rec. 709 luminance weights of red, green and blue.
const _lr = 0.2126;
const _lg = 0.7152;
const _lb = 0.0722;

/// [first] then [second]: the transform that applies [first] and then
/// [second] to a color.
ColorMatrix compose(ColorMatrix first, ColorMatrix second) {
  assert(first.length == 20 && second.length == 20, 'matrices are 4 × 5');
  final result = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var column = 0; column < 5; column++) {
      var value = column == 4 ? second[row * 5 + 4] : 0.0;
      for (var k = 0; k < 4; k++) {
        value += second[row * 5 + k] * first[k * 5 + column];
      }
      result[row * 5 + column] = value;
    }
  }
  return result;
}

/// Scales red, green and blue by [r], [g], [b] and adds [offset] to each.
ColorMatrix _scale(double r, double g, double b, [double offset = 0]) => [
  r, 0, 0, 0, offset, //
  0, g, 0, 0, offset,
  0, 0, b, 0, offset,
  0, 0, 0, 1, 0,
];

/// Brightness [amount] (-1 to 1): adds up to a quarter of the range.
ColorMatrix brightnessMatrix(double amount) => _scale(1, 1, 1, amount * 64);

/// Exposure [amount] (-1 to 1): multiplies by 2^amount, one stop each way.
ColorMatrix exposureMatrix(double amount) {
  final gain = math.pow(2, amount).toDouble();
  return _scale(gain, gain, gain);
}

/// Contrast [amount] (-1 to 1) around mid-gray: from flat (×0.25) to
/// strong (×2).
ColorMatrix contrastMatrix(double amount) {
  final factor = amount >= 0 ? 1 + amount : 1 + amount * 0.75;
  return _scale(factor, factor, factor, 127.5 * (1 - factor));
}

/// Saturation [amount] (-1 to 1): -1 is black and white, 1 doubles the
/// colors, luminance unchanged.
ColorMatrix saturationMatrix(double amount) {
  final s = 1 + amount;
  final r = (1 - s) * _lr;
  final g = (1 - s) * _lg;
  final b = (1 - s) * _lb;
  return [
    r + s, g, b, 0, 0, //
    r, g + s, b, 0, 0,
    r, g, b + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Warmth [amount] (-1 to 1): more red and less blue when warmer, the
/// other way round when cooler.
ColorMatrix warmthMatrix(double amount) =>
    _scale(1 + amount * 0.12, 1 + amount * 0.02, 1 - amount * 0.12);

/// The transform of [adjustments]: exposure, brightness, contrast,
/// saturation, then warmth.
ColorMatrix adjustmentMatrix(Adjustments adjustments) => [
  exposureMatrix(adjustments.exposure),
  brightnessMatrix(adjustments.brightness),
  contrastMatrix(adjustments.contrast),
  saturationMatrix(adjustments.saturation),
  warmthMatrix(adjustments.warmth),
].fold(identityMatrix, compose);

/// [filter] at full strength.
ColorMatrix _filterMatrix(PhotoFilter filter) => switch (filter) {
  PhotoFilter.none => identityMatrix,
  PhotoFilter.blackAndWhite => saturationMatrix(-1),
  PhotoFilter.sepia => const [
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ],
  PhotoFilter.vintage => [
    saturationMatrix(-0.3),
    warmthMatrix(0.6),
    _scale(0.85, 0.85, 0.85, 24),
  ].fold(identityMatrix, compose),
  PhotoFilter.warm => compose(warmthMatrix(0.6), saturationMatrix(0.1)),
  PhotoFilter.cool => compose(warmthMatrix(-0.6), saturationMatrix(-0.05)),
  PhotoFilter.vivid => compose(saturationMatrix(0.5), contrastMatrix(0.15)),
  PhotoFilter.fade => compose(
    saturationMatrix(-0.25),
    _scale(0.8, 0.8, 0.8, 32),
  ),
  PhotoFilter.dramatic => [
    exposureMatrix(-0.15),
    contrastMatrix(0.45),
    saturationMatrix(-0.2),
  ].fold(identityMatrix, compose),
  PhotoFilter.noir => [
    saturationMatrix(-1),
    brightnessMatrix(-0.1),
    contrastMatrix(0.6),
  ].fold(identityMatrix, compose),
  PhotoFilter.soft => [
    brightnessMatrix(0.1),
    contrastMatrix(-0.25),
    saturationMatrix(-0.1),
  ].fold(identityMatrix, compose),
};

/// The transform of [filter] at [strength] (0 to 1): a blend between no
/// change and the full filter, which for a linear transform is the same
/// as blending the colors.
ColorMatrix filterMatrix(PhotoFilter filter, [double strength = 1]) {
  final full = _filterMatrix(filter);
  return [
    for (var i = 0; i < 20; i++)
      identityMatrix[i] + (full[i] - identityMatrix[i]) * strength,
  ];
}

/// The color transform of [edit]: its filter, then its adjustments.
ColorMatrix editMatrix(PhotoEdit edit) => compose(
  filterMatrix(edit.filter, edit.filterStrength),
  adjustmentMatrix(edit.adjustments),
);

/// [matrix] applied to an opaque color of [r], [g], [b] (0 to 255), each
/// channel clamped to 0–255, as the screen and the saved photo do.
(double, double, double) applyMatrix(
  ColorMatrix matrix,
  double r,
  double g,
  double b,
) {
  double channel(int row) =>
      (matrix[row * 5] * r +
              matrix[row * 5 + 1] * g +
              matrix[row * 5 + 2] * b +
              matrix[row * 5 + 3] * 255 +
              matrix[row * 5 + 4])
          .clamp(0, 255);
  return (channel(0), channel(1), channel(2));
}
