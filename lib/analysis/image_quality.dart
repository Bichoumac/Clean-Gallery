import 'dart:math' as math;

import 'package:clean_gallery/domain/gray_image.dart';

/// Sharpness, brightness and contrast of a photo, measured on its
/// grayscale thumbnail. See `docs/analysis-engine.md#blurry-and-dark-photos`.
typedef ImageQuality = ({double sharpness, double brightness, double contrast});

/// Below this sharpness ([ImageQuality]), a photo is offered as blurry.
///
/// Variance of the Laplacian on a thumbnail fitting in 256 × 256 pixels: a
/// thumbnail is sharper than its photo, so the usual full-size thresholds
/// (around 100) do not apply. On the synthetic test photos, sharp ones
/// score 54 to 250 (recompressed included), the same blurred by 0.6 % of
/// their width 7 to 19. To check on real photos.
const blurryBelow = 30.0;

/// From this [relativeSharpness], a photo below [blurryBelow] is hazy
/// (mist, fog, a night scene), not blurry: its edges are soft because the
/// whole photo has little contrast, and they are sharp for that contrast.
///
/// Set on the product owner's photos on 2026-10-27: hazy night photos with
/// lights score 150 and more, really blurry ones less.
const hazyFrom = 150.0;

/// Below this brightness ([ImageQuality], mean of 0–255), a photo is
/// offered as too dark: a pocket shot or a covered lens.
const darkBelow = 20.0;

/// [ImageQuality] of [image]:
///
/// - sharpness: variance of the 4-neighbour Laplacian over the inner
///   pixels. Edges give large values; a blurred photo has soft edges and a
///   low variance. Higher is sharper;
/// - brightness: mean of the pixels, 0 (black) to 255 (white);
/// - contrast: standard deviation of the pixels, 0 for a flat image.
ImageQuality imageQuality(GrayImage image) {
  final width = image.width;
  final height = image.height;
  final pixels = image.pixels;
  var total = 0;
  var totalSquares = 0;
  for (final value in pixels) {
    total += value;
    totalSquares += value * value;
  }
  final brightness = total / pixels.length;
  final variance = totalSquares / pixels.length - brightness * brightness;
  final contrast = math.sqrt(math.max(0, variance));
  if (width < 3 || height < 3) {
    return (sharpness: 0, brightness: brightness, contrast: contrast);
  }

  var sum = 0.0;
  var squares = 0.0;
  for (var y = 1; y < height - 1; y++) {
    final row = y * width;
    for (var x = 1; x < width - 1; x++) {
      final i = row + x;
      final laplacian =
          pixels[i - width] +
          pixels[i + width] +
          pixels[i - 1] +
          pixels[i + 1] -
          4 * pixels[i];
      sum += laplacian;
      squares += laplacian * laplacian;
    }
  }
  final count = (width - 2) * (height - 2);
  final mean = sum / count;
  return (
    sharpness: squares / count - mean * mean,
    brightness: brightness,
    contrast: contrast,
  );
}

/// Sharpness for the photo's contrast: the variance of the Laplacian over
/// the variance of the pixels, × 1000. Lowering the contrast of a photo
/// lowers both alike, so a hazy photo keeps the value of a clear one,
/// while blur lowers it. `0` for a flat image.
double relativeSharpness({
  required double sharpness,
  required double contrast,
}) => contrast <= 0 ? 0 : sharpness * 1000 / (contrast * contrast);

/// Whether a photo of [sharpness] and [contrast] is blurry: soft edges
/// ([blurryBelow]) that are soft for its contrast too ([hazyFrom]). Without
/// a known contrast (measured before analysis version 3), the sharpness
/// alone decides.
bool isBlurry({required double sharpness, double? contrast}) =>
    sharpness < blurryBelow &&
    (contrast == null ||
        relativeSharpness(sharpness: sharpness, contrast: contrast) < hazyFrom);

/// Whether a photo of [quality] is offered for cleaning: blurry or too
/// dark.
bool isPoorQuality(ImageQuality quality) =>
    isBlurry(sharpness: quality.sharpness, contrast: quality.contrast) ||
    quality.brightness < darkBelow;
