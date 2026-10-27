import 'package:clean_gallery/domain/gray_image.dart';

/// Sharpness and brightness of a photo, measured on its grayscale
/// thumbnail. See `docs/analysis-engine.md#blurry-and-dark-photos`.
typedef ImageQuality = ({double sharpness, double brightness});

/// Below this sharpness ([ImageQuality]), a photo is offered as blurry.
///
/// Variance of the Laplacian on a thumbnail fitting in 256 × 256 pixels: a
/// thumbnail is sharper than its photo, so the usual full-size thresholds
/// (around 100) do not apply. On the synthetic test photos, sharp ones
/// score 54 to 250 (recompressed included), the same blurred by 0.6 % of
/// their width 7 to 19. To check on real photos.
const blurryBelow = 30.0;

/// Below this brightness ([ImageQuality], mean of 0–255), a photo is
/// offered as too dark: a pocket shot or a covered lens.
const darkBelow = 20.0;

/// [ImageQuality] of [image]:
///
/// - sharpness: variance of the 4-neighbour Laplacian over the inner
///   pixels. Edges give large values; a blurred photo has soft edges and a
///   low variance. Higher is sharper;
/// - brightness: mean of the pixels, 0 (black) to 255 (white).
ImageQuality imageQuality(GrayImage image) {
  final width = image.width;
  final height = image.height;
  final pixels = image.pixels;
  var total = 0;
  for (final value in pixels) {
    total += value;
  }
  final brightness = total / pixels.length;
  if (width < 3 || height < 3) return (sharpness: 0, brightness: brightness);

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
  return (sharpness: squares / count - mean * mean, brightness: brightness);
}

/// Whether a photo of [quality] is offered for cleaning: blurry or too
/// dark.
bool isPoorQuality(ImageQuality quality) =>
    quality.sharpness < blurryBelow || quality.brightness < darkBelow;
