import 'dart:math' as math;
import 'dart:typed_data';

import 'package:clean_gallery/domain/gray_image.dart';

/// The two 64-bit perceptual hashes of a photo.
///
/// Similar pictures (resized, recompressed, slightly edited) get hashes a
/// few bits apart; [hammingDistance] counts those bits. See
/// `docs/analysis-engine.md#similar-photos`.
typedef PerceptualHashes = ({int dHash, int pHash});

/// Side of the image the pHash's DCT runs on.
const _dctSide = 32;

/// Rows and columns of DCT coefficients kept by the pHash.
const _kept = 8;

/// Both perceptual hashes of [image].
PerceptualHashes perceptualHashes(GrayImage image) =>
    (dHash: differenceHash(image), pHash: perceptualHash(image));

/// Difference hash: the image is shrunk to 9 × 8 and each bit says whether
/// a pixel is darker than its right neighbour. Fast, robust to scaling and
/// brightness, sensitive to cropping.
int differenceHash(GrayImage image) {
  final small = resizeArea(image, 9, 8);
  var hash = 0;
  var bit = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      if (small[y * 9 + x] < small[y * 9 + x + 1]) hash |= 1 << bit;
      bit++;
    }
  }
  return hash;
}

/// Perceptual hash: the image is shrunk to 32 × 32 and transformed by a
/// DCT; each bit says whether one of the 64 lowest frequencies (the DC row
/// and column left out) is above their median. Robust to scaling,
/// recompression, brightness and small edits.
int perceptualHash(GrayImage image) {
  final small = resizeArea(image, _dctSide, _dctSide);
  final cos = _cosines;
  // Rows 1..8 of C · X, then columns 1..8 of (C · X) · Cᵀ: only the kept
  // coefficients are computed.
  final rows = Float64List((_kept + 1) * _dctSide);
  for (var u = 1; u <= _kept; u++) {
    for (var x = 0; x < _dctSide; x++) {
      var sum = 0.0;
      for (var y = 0; y < _dctSide; y++) {
        sum += cos[u * _dctSide + y] * small[y * _dctSide + x];
      }
      rows[u * _dctSide + x] = sum;
    }
  }
  final coefficients = Float64List(_kept * _kept);
  for (var u = 1; u <= _kept; u++) {
    for (var v = 1; v <= _kept; v++) {
      var sum = 0.0;
      for (var x = 0; x < _dctSide; x++) {
        sum += rows[u * _dctSide + x] * cos[v * _dctSide + x];
      }
      coefficients[(u - 1) * _kept + (v - 1)] = sum;
    }
  }
  final sorted = Float64List.fromList(coefficients)..sort();
  final median = (sorted[31] + sorted[32]) / 2;
  var hash = 0;
  for (var i = 0; i < 64; i++) {
    if (coefficients[i] > median) hash |= 1 << i;
  }
  return hash;
}

/// DCT-II basis, `cos(π (2x + 1) u / 64)` at `[u * 32 + x]`. Scale factors
/// are left out: they do not change which coefficients are above the
/// median within a row or column band.
final Float64List _cosines = () {
  final table = Float64List(_dctSide * _dctSide);
  for (var u = 0; u < _dctSide; u++) {
    for (var x = 0; x < _dctSide; x++) {
      table[u * _dctSide + x] = math.cos(
        math.pi * (2 * x + 1) * u / (2 * _dctSide),
      );
    }
  }
  return table;
}();

/// Number of bits that differ between hashes [a] and [b], 0 to 64.
int hammingDistance(int a, int b) {
  final v = a ^ b;
  var count = 0;
  for (var shift = 0; shift < 64; shift += 8) {
    count += _bitsInByte[(v >>> shift) & 0xFF];
  }
  return count;
}

/// Number of set bits of each byte value.
final Uint8List _bitsInByte = () {
  final table = Uint8List(256);
  for (var i = 1; i < 256; i++) {
    table[i] = (i & 1) + table[i >> 1];
  }
  return table;
}();

/// [image] resized to [width] × [height] by area averaging: each target
/// pixel is the mean of the source area it covers, so shrinking does not
/// alias. Enlarging repeats pixels.
Float64List resizeArea(GrayImage image, int width, int height) {
  // Rows first (image.width → width), then columns (image.height → height).
  final rows = _resizeAxis(
    image.pixels,
    lines: image.height,
    from: image.width,
    to: width,
    sourceLine: image.width,
    sourceStep: 1,
    resultLine: width,
    resultStep: 1,
  );
  return _resizeAxis(
    rows,
    lines: width,
    from: image.height,
    to: height,
    sourceLine: 1,
    sourceStep: width,
    resultLine: 1,
    resultStep: width,
  );
}

/// Resizes [lines] lines of [from] samples to [to] samples. In [source], a
/// line starts every [sourceLine] values and its samples are [sourceStep]
/// apart; [resultLine] and [resultStep] are the same for the result.
Float64List _resizeAxis(
  List<num> source, {
  required int lines,
  required int from,
  required int to,
  required int sourceLine,
  required int sourceStep,
  required int resultLine,
  required int resultStep,
}) {
  final result = Float64List(lines * to);
  final scale = from / to;
  for (var line = 0; line < lines; line++) {
    for (var i = 0; i < to; i++) {
      final start = i * scale;
      final end = start + scale;
      final last = math.min(end.ceil(), from);
      var sum = 0.0;
      for (var s = start.floor(); s < last; s++) {
        final overlap = math.min(end, s + 1.0) - math.max(start, s.toDouble());
        sum += overlap * source[line * sourceLine + s * sourceStep];
      }
      result[line * resultLine + i * resultStep] = sum / scale;
    }
  }
  return result;
}
