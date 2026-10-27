import 'dart:math' as math;
import 'dart:typed_data';

import 'package:clean_gallery/domain/gray_image.dart';
import 'package:image/image.dart' as img;

/// Synthetic test photos for the similar photo engine, made in memory so
/// the repository holds no image files and no personal content.
///
/// A scene is a gradient sky with soft shapes and fine texture, drawn from
/// a seed: two seeds give unrelated photos, one seed always gives the same
/// photo. Variants mimic what happens to a photo on a phone: recompression,
/// resizing, a brightness edit, a slight crop.
abstract final class PhotoSet {
  /// The scene of [seed], [width] × [height] pixels. With [shift], its
  /// shapes are drawn [shift] pixels further right: the same place with the
  /// subject moved, as in two shots taken in a row.
  static img.Image scene(
    int seed, {
    int width = 480,
    int height = 360,
    int shift = 0,
  }) {
    final random = math.Random(seed);
    final image = img.Image(width: width, height: height);
    final top = _color(random);
    final bottom = _color(random);
    for (var y = 0; y < height; y++) {
      final t = y / (height - 1);
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(
          x,
          y,
          _mix(top.$1, bottom.$1, t),
          _mix(top.$2, bottom.$2, t),
          _mix(top.$3, bottom.$3, t),
        );
      }
    }
    for (var i = 0; i < 6 + random.nextInt(5); i++) {
      final (r, g, b) = _color(random);
      final x = random.nextInt(width) + shift;
      final y = random.nextInt(height);
      final size = 20 + random.nextInt(width ~/ 4);
      if (random.nextBool()) {
        img.fillCircle(
          image,
          x: x,
          y: y,
          radius: size ~/ 2,
          color: img.ColorRgb8(r, g, b),
        );
      } else {
        img.fillRect(
          image,
          x1: x,
          y1: y,
          x2: x + size,
          y2: y + size * 2 ~/ 3,
          color: img.ColorRgb8(r, g, b),
        );
      }
    }
    // Sensor-like grain, the same for a seed.
    final grain = math.Random(seed * 31 + 7);
    for (final pixel in image) {
      final n = grain.nextInt(13) - 6;
      pixel
        ..r = (pixel.r + n).clamp(0, 255)
        ..g = (pixel.g + n).clamp(0, 255)
        ..b = (pixel.b + n).clamp(0, 255);
    }
    return image;
  }

  /// [image] saved as a JPEG of [quality] and read back.
  static img.Image recompressed(img.Image image, {int quality = 40}) =>
      img.decodeJpg(img.encodeJpg(image, quality: quality))!;

  /// [image] scaled by [factor].
  static img.Image resized(img.Image image, double factor) => img.copyResize(
    image,
    width: (image.width * factor).round(),
    height: (image.height * factor).round(),
    interpolation: img.Interpolation.average,
  );

  /// [image] made brighter by [amount] (0–255).
  static img.Image brightened(img.Image image, int amount) {
    final copy = image.clone();
    for (final pixel in copy) {
      pixel
        ..r = (pixel.r + amount).clamp(0, 255)
        ..g = (pixel.g + amount).clamp(0, 255)
        ..b = (pixel.b + amount).clamp(0, 255);
    }
    return copy;
  }

  /// [image] with [fraction] of each side cropped away.
  static img.Image cropped(img.Image image, double fraction) {
    final dx = (image.width * fraction).round();
    final dy = (image.height * fraction).round();
    return img.copyCrop(
      image,
      x: dx,
      y: dy,
      width: image.width - 2 * dx,
      height: image.height - 2 * dy,
    );
  }

  /// [image] out of focus: a gaussian blur of [radius] pixels.
  static img.Image blurred(img.Image image, int radius) =>
      img.gaussianBlur(image.clone(), radius: radius);

  /// [image] with its brightness scaled by [factor] (0–1): an underexposed
  /// shot.
  static img.Image darkened(img.Image image, double factor) {
    final copy = image.clone();
    for (final pixel in copy) {
      pixel
        ..r = (pixel.r * factor).round()
        ..g = (pixel.g * factor).round()
        ..b = (pixel.b * factor).round();
    }
    return copy;
  }

  /// [image] as the platform hands it to the engine: a grayscale thumbnail
  /// fitting in [side] × [side] (256, as the scan asks for).
  static GrayImage thumbnail(img.Image image, {int side = 256}) {
    final scale = side / math.max(image.width, image.height);
    final small = img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      height: math.max(1, (image.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
    final pixels = Uint8List(small.width * small.height);
    var i = 0;
    for (final pixel in small) {
      pixels[i++] = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
          .round();
    }
    return GrayImage(width: small.width, height: small.height, pixels: pixels);
  }

  static (int, int, int) _color(math.Random random) =>
      (random.nextInt(256), random.nextInt(256), random.nextInt(256));

  static int _mix(int a, int b, double t) => (a + (b - a) * t).round();
}
