import 'dart:typed_data';

/// A small grayscale image: one byte of brightness (0–255) per pixel, row
/// by row.
///
/// The analysis engine works on these instead of full photos: the platform
/// renders them from its thumbnail cache, so they are cheap to get and to
/// send to an isolate.
final class GrayImage {
  /// Creates an image of [width] × [height] [pixels].
  GrayImage({required this.width, required this.height, required this.pixels})
    : assert(width > 0 && height > 0, 'An image needs pixels'),
      assert(pixels.length == width * height, 'One byte per pixel');

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Brightness of each pixel, row by row.
  final Uint8List pixels;
}
