import 'dart:math' as math;
import 'dart:typed_data';

import 'package:clean_gallery/analysis/color_matrix.dart';
import 'package:clean_gallery/domain/gray_image.dart';

/// A point, in fractions of an image's width and height, or in pixels.
typedef Point = (double, double);

/// Smallest share of the image a detected document may cover.
const minDocumentArea = 0.1;

/// Corners used when no document is found: a frame inset by 8 %.
const defaultCorners = <Point>[
  (0.08, 0.08),
  (0.92, 0.08),
  (0.92, 0.92),
  (0.08, 0.92),
];

/// Grayscale copy of [rgba] ([width] × [height], 4 bytes per pixel), at
/// most [maxSide] pixels on its longest side, for [detectDocument].
GrayImage grayFromRgba(
  Uint8List rgba,
  int width,
  int height, {
  int maxSide = 200,
}) {
  final step = math.max(1, (math.max(width, height) / maxSide).ceil());
  final w = math.max(1, width ~/ step);
  final h = math.max(1, height ~/ step);
  final pixels = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = ((y * step) * width + x * step) * 4;
      pixels[y * w +
          x] = (0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2])
          .round();
    }
  }
  return GrayImage(width: w, height: h, pixels: pixels);
}

/// The threshold splitting [histogram] into two classes with the largest
/// variance between them (Otsu's method).
int otsuThreshold(List<int> histogram) {
  final total = histogram.fold(0, (sum, n) => sum + n);
  var sum = 0.0;
  for (var v = 0; v < 256; v++) {
    sum += v * histogram[v];
  }
  var below = 0;
  var sumBelow = 0.0;
  var best = 0.0;
  var threshold = 127;
  for (var v = 0; v < 256; v++) {
    below += histogram[v];
    if (below == 0) continue;
    final above = total - below;
    if (above == 0) break;
    sumBelow += v * histogram[v];
    final meanBelow = sumBelow / below;
    final meanAbove = (sum - sumBelow) / above;
    final between = below * above * math.pow(meanBelow - meanAbove, 2);
    if (between > best) {
      best = between.toDouble();
      threshold = v;
    }
  }
  return threshold;
}

/// The four corners of the sheet of paper in [image] — top left, top right,
/// bottom right, bottom left, in fractions — or `null` when none stands
/// out.
///
/// Paper is lighter than what it lies on: the image is split in light and
/// dark by [otsuThreshold], the largest light area in one piece is taken
/// as the sheet, and its corners are its points furthest along the
/// diagonals (smallest and largest x + y and x − y). No machine learning;
/// a sheet on a light table, or folded, may not be found: the user then
/// places the corners.
List<Point>? detectDocument(GrayImage image) {
  final w = image.width;
  final h = image.height;
  final histogram = List<int>.filled(256, 0);
  for (final p in image.pixels) {
    histogram[p]++;
  }
  final threshold = otsuThreshold(histogram);
  final seen = Uint8List(w * h);
  final queue = Int32List(w * h);
  var bestSize = 0;
  List<int>? bestCorners;
  for (var start = 0; start < w * h; start++) {
    if (seen[start] != 0 || image.pixels[start] <= threshold) continue;
    // Flood fill one light area, tracking its extreme points.
    var head = 0;
    var tail = 0;
    queue[tail++] = start;
    seen[start] = 1;
    var minSum = 1 << 30;
    var maxSum = -1;
    var minDiff = 1 << 30;
    var maxDiff = -(1 << 30);
    var tl = start;
    var br = start;
    var bl = start;
    var tr = start;
    while (head < tail) {
      final i = queue[head++];
      final x = i % w;
      final y = i ~/ w;
      if (x + y < minSum) {
        minSum = x + y;
        tl = i;
      }
      if (x + y > maxSum) {
        maxSum = x + y;
        br = i;
      }
      if (x - y < minDiff) {
        minDiff = x - y;
        bl = i;
      }
      if (x - y > maxDiff) {
        maxDiff = x - y;
        tr = i;
      }
      for (final n in [
        if (x > 0) i - 1,
        if (x < w - 1) i + 1,
        if (y > 0) i - w,
        if (y < h - 1) i + w,
      ]) {
        if (seen[n] == 0 && image.pixels[n] > threshold) {
          seen[n] = 1;
          queue[tail++] = n;
        }
      }
    }
    if (tail > bestSize) {
      bestSize = tail;
      bestCorners = [tl, tr, br, bl];
    }
  }
  if (bestCorners == null || bestSize < minDocumentArea * w * h) return null;
  // A light area covering the whole image is the background, not a sheet.
  if (bestSize > 0.97 * w * h) return null;
  return [
    for (final i in bestCorners) (((i % w) + 0.5) / w, ((i ~/ w) + 0.5) / h),
  ];
}

/// The 3 × 3 projective transform (row by row, last value 1) taking each
/// of the four points [from] to the matching point of [to].
List<double> homography(List<Point> from, List<Point> to) {
  // Eight equations in the eight unknowns a…h of
  // x' = (a x + b y + c) / (g x + h y + 1), y' = (d x + e y + f) / (…).
  final rows = <List<double>>[];
  for (var k = 0; k < 4; k++) {
    final (x, y) = from[k];
    final (u, v) = to[k];
    rows
      ..add([x, y, 1, 0, 0, 0, -u * x, -u * y, u])
      ..add([0, 0, 0, x, y, 1, -v * x, -v * y, v]);
  }
  // Gaussian elimination with partial pivoting.
  for (var col = 0; col < 8; col++) {
    var pivot = col;
    for (var r = col + 1; r < 8; r++) {
      if (rows[r][col].abs() > rows[pivot][col].abs()) pivot = r;
    }
    final swap = rows[col];
    rows[col] = rows[pivot];
    rows[pivot] = swap;
    final p = rows[col][col];
    if (p.abs() < 1e-12) throw ArgumentError('degenerate corners');
    for (var c = col; c < 9; c++) {
      rows[col][c] /= p;
    }
    for (var r = 0; r < 8; r++) {
      if (r == col) continue;
      final f = rows[r][col];
      if (f == 0) continue;
      for (var c = col; c < 9; c++) {
        rows[r][c] -= f * rows[col][c];
      }
    }
  }
  return [for (var r = 0; r < 8; r++) rows[r][8], 1];
}

/// [point] taken through [h] (from [homography]).
Point applyHomography(List<double> h, Point point) {
  final (x, y) = point;
  final d = h[6] * x + h[7] * y + h[8];
  return ((h[0] * x + h[1] * y + h[2]) / d, (h[3] * x + h[4] * y + h[5]) / d);
}

double _distance(Point a, Point b) =>
    math.sqrt(math.pow(a.$1 - b.$1, 2) + math.pow(a.$2 - b.$2, 2));

/// Width and height of the flat page whose [corners] (in pixels: top left,
/// top right, bottom right, bottom left) were photographed: its longer
/// opposite sides.
(double, double) pageSize(List<Point> corners) => (
  math.max(
    _distance(corners[0], corners[1]),
    _distance(corners[3], corners[2]),
  ),
  math.max(
    _distance(corners[0], corners[3]),
    _distance(corners[1], corners[2]),
  ),
);

/// How a scanned page is rendered.
enum DocumentMode {
  /// Colors kept, light stretched.
  color,

  /// Shades of gray, light stretched.
  gray,

  /// Black text on white paper.
  blackWhite,
}

/// The value below which [share] of the pixels of [histogram] fall.
int _percentile(List<int> histogram, double share) {
  final total = histogram.fold(0, (sum, n) => sum + n);
  var seen = 0;
  for (var v = 0; v < 256; v++) {
    seen += histogram[v];
    if (seen > total * share) return v;
  }
  return 255;
}

/// Gray with Rec. 709 weights.
const ColorMatrix _grayMatrix = [
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

/// Maps [low] to black and [high] to white, linearly.
ColorMatrix _levels(int low, int high) {
  final gain = 255 / math.max(1, high - low);
  final offset = -low * gain;
  return [
    gain, 0, 0, 0, offset, //
    0, gain, 0, 0, offset,
    0, 0, gain, 0, offset,
    0, 0, 0, 1, 0,
  ];
}

/// The color matrix rendering a page in [mode], from the luminance
/// [histogram] of the flattened page. A page is mostly paper: in black and
/// white, everything as light as the median paper becomes white and the
/// darkest 2 % (the ink) black, so shadows and yellowed paper disappear.
ColorMatrix documentMatrix(DocumentMode mode, List<int> histogram) =>
    switch (mode) {
      DocumentMode.color => _levels(
        _percentile(histogram, 0.005),
        _percentile(histogram, 0.995),
      ),
      DocumentMode.gray => compose(
        _grayMatrix,
        _levels(_percentile(histogram, 0.005), _percentile(histogram, 0.995)),
      ),
      DocumentMode.blackWhite => compose(
        _grayMatrix,
        _levels(
          _percentile(histogram, 0.02),
          (_percentile(histogram, 0.5) * 0.92).round(),
        ),
      ),
    };
