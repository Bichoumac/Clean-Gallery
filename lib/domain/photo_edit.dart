import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'photo_edit.freezed.dart';

/// Smallest side of a crop, as a fraction of the photo's side.
const minCropSide = 0.1;

/// A rectangle inside a photo, in fractions of its width and height (0 to
/// 1), in the photo's orientation after rotation and flip: what the user
/// sees in the editor.
@freezed
abstract class CropRect with _$CropRect {
  /// Creates a rectangle from its edges.
  const factory CropRect({
    @Default(0) double left,
    @Default(0) double top,
    @Default(1) double right,
    @Default(1) double bottom,
  }) = _CropRect;

  const CropRect._();

  /// The whole photo.
  static const full = CropRect();

  /// Width, as a fraction of the photo's width.
  double get width => right - left;

  /// Height, as a fraction of the photo's height.
  double get height => bottom - top;

  /// Whether this is the whole photo.
  bool get isFull => left <= 0 && top <= 0 && right >= 1 && bottom >= 1;

  /// The same area once the photo is turned a quarter clockwise.
  CropRect rotatedClockwise() =>
      CropRect(left: 1 - bottom, top: left, right: 1 - top, bottom: right);

  /// The same area once the photo is mirrored left to right.
  CropRect flipped() => copyWith(left: 1 - right, right: 1 - left);

  /// This rectangle moved by [dx], [dy] (fractions), kept inside the photo.
  CropRect moved(double dx, double dy) {
    final x = (left + dx).clamp(0.0, 1 - width);
    final y = (top + dy).clamp(0.0, 1 - height);
    return CropRect(left: x, top: y, right: x + width, bottom: y + height);
  }
}

/// A crop shape: free, or a fixed width-to-height ratio.
enum CropRatio {
  /// Any shape.
  free(null),

  /// The photo's own proportions.
  original(null),

  /// Square.
  square(1),

  /// 4:3, landscape.
  fourThree(4 / 3),

  /// 3:4, portrait.
  threeFour(3 / 4),

  /// 16:9, landscape.
  sixteenNine(16 / 9),

  /// 9:16, portrait.
  nineSixteen(9 / 16);

  CropRatio(this.value);

  /// Width divided by height, in pixels; `null` for [free] and [original].
  final double? value;

  /// The ratio in pixels for a photo of [photoRatio] (width / height), or
  /// `null` when the shape is free.
  double? pixelRatio(double photoRatio) => switch (this) {
    free => null,
    original => photoRatio,
    _ => value,
  };
}

/// Where the user grabbed a crop rectangle.
enum CropHandle {
  /// Inside: moves the rectangle.
  inside,

  /// Top left corner.
  topLeft,

  /// Top right corner.
  topRight,

  /// Bottom left corner.
  bottomLeft,

  /// Bottom right corner.
  bottomRight,
}

/// The largest rectangle of [pixelRatio] (width / height, in pixels) inside
/// a photo of [photoRatio], centered on [around]'s center and kept inside
/// the photo. Used when the user picks a ratio.
CropRect fitRatio(CropRect around, double pixelRatio, double photoRatio) {
  // In fractions, width / height = pixelRatio / photoRatio.
  final fractionRatio = pixelRatio / photoRatio;
  var width = 1.0;
  var height = width / fractionRatio;
  if (height > 1) {
    height = 1;
    width = fractionRatio;
  }
  final cx = (around.left + around.right) / 2;
  final cy = (around.top + around.bottom) / 2;
  final left = (cx - width / 2).clamp(0.0, 1 - width);
  final top = (cy - height / 2).clamp(0.0, 1 - height);
  return CropRect(
    left: left,
    top: top,
    right: left + width,
    bottom: top + height,
  );
}

/// [rect] with the corner [handle] dragged by [dx], [dy] (fractions), the
/// opposite corner fixed. With [pixelRatio], the shape keeps that ratio
/// (the width follows the finger, the height the width). Never smaller than
/// [minCropSide] nor outside the photo.
CropRect dragCorner(
  CropRect rect,
  CropHandle handle,
  double dx,
  double dy, {
  double? pixelRatio,
  double photoRatio = 1,
}) {
  final movesLeft =
      handle == CropHandle.topLeft || handle == CropHandle.bottomLeft;
  final movesTop =
      handle == CropHandle.topLeft || handle == CropHandle.topRight;
  // Fixed corner, and the corner under the finger.
  final fixedX = movesLeft ? rect.right : rect.left;
  final fixedY = movesTop ? rect.bottom : rect.top;
  var x = (movesLeft ? rect.left : rect.right) + dx;
  var y = (movesTop ? rect.top : rect.bottom) + dy;
  // Room up to the photo's edge in the direction of the drag.
  final roomX = movesLeft ? fixedX : 1 - fixedX;
  final roomY = movesTop ? fixedY : 1 - fixedY;
  // Extent in the direction of the drag: a finger past the fixed corner
  // gives the smallest crop, not a mirrored one.
  var width = (movesLeft ? fixedX - x : x - fixedX).clamp(minCropSide, roomX);
  var height = (movesTop ? fixedY - y : y - fixedY).clamp(minCropSide, roomY);
  if (pixelRatio != null) {
    final fractionRatio = pixelRatio / photoRatio;
    height = width / fractionRatio;
    if (height > roomY) {
      height = roomY;
      width = height * fractionRatio;
    }
    if (height < minCropSide) {
      height = minCropSide;
      width = math.min(height * fractionRatio, roomX);
    }
  }
  x = movesLeft ? fixedX - width : fixedX + width;
  y = movesTop ? fixedY - height : fixedY + height;
  return CropRect(
    left: math.min(x, fixedX),
    top: math.min(y, fixedY),
    right: math.max(x, fixedX),
    bottom: math.max(y, fixedY),
  );
}

/// Color adjustments of a photo, each from -1 to 1, 0 leaving the photo
/// unchanged.
@freezed
abstract class Adjustments with _$Adjustments {
  /// Creates adjustments.
  const factory Adjustments({
    @Default(0) double brightness,
    @Default(0) double contrast,
    @Default(0) double saturation,
    @Default(0) double exposure,
    @Default(0) double warmth,

    /// Darker edges (positive) or lighter edges (negative), drawing the eye
    /// to the center. Not a color matrix: painted as a radial gradient.
    @Default(0) double vignette,
  }) = _Adjustments;

  const Adjustments._();

  /// Whether nothing is adjusted.
  bool get isNeutral =>
      brightness == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      exposure == 0 &&
      warmth == 0 &&
      vignette == 0;
}

/// One of the [Adjustments].
enum Adjustment {
  /// Lighter or darker, evenly.
  brightness,

  /// Stronger or softer difference between light and dark.
  contrast,

  /// More or less vivid colors.
  saturation,

  /// Like opening or closing the lens: bright parts gain more.
  exposure,

  /// Warmer (orange) or cooler (blue).
  warmth,

  /// Darker (or lighter) edges.
  vignette;

  /// The value of this adjustment in [adjustments].
  double of(Adjustments adjustments) => switch (this) {
    brightness => adjustments.brightness,
    contrast => adjustments.contrast,
    saturation => adjustments.saturation,
    exposure => adjustments.exposure,
    warmth => adjustments.warmth,
    vignette => adjustments.vignette,
  };

  /// [adjustments] with this adjustment set to [value].
  Adjustments set(Adjustments adjustments, double value) => switch (this) {
    brightness => adjustments.copyWith(brightness: value),
    contrast => adjustments.copyWith(contrast: value),
    saturation => adjustments.copyWith(saturation: value),
    exposure => adjustments.copyWith(exposure: value),
    warmth => adjustments.copyWith(warmth: value),
    vignette => adjustments.copyWith(vignette: value),
  };
}

/// What a [Stroke] does where it passes.
enum StrokeKind {
  /// Paints a line of its color.
  pen,

  /// Blurs the photo, e.g. a face or a plate.
  blur,

  /// Turns the photo into large squares.
  pixelate,
}

/// A line drawn with the pencil: a color, or a blurred or pixelated area.
@freezed
abstract class Stroke with _$Stroke {
  /// Creates a stroke.
  const factory Stroke({
    /// Points, in fractions of the rotated and flipped photo (like the
    /// crop), in drawing order.
    required List<(double, double)> points,

    /// Color as 0xAARRGGBB.
    required int color,

    /// Line width, as a fraction of the photo's shorter side, which turning
    /// the photo does not change.
    required double width,

    /// What the line does.
    @Default(StrokeKind.pen) StrokeKind kind,
  }) = _Stroke;

  const Stroke._();

  /// The same line once the photo is turned a quarter clockwise.
  Stroke rotatedClockwise() =>
      copyWith(points: [for (final (x, y) in points) (1 - y, x)]);

  /// The same line once the photo is mirrored left to right.
  Stroke flipped() =>
      copyWith(points: [for (final (x, y) in points) (1 - x, y)]);
}

/// Typeface of a [TextItem].
enum TextFont {
  /// The app's own font (Manrope).
  sans,

  /// A serif face.
  serif,

  /// A fixed-width face.
  mono,

  /// A handwriting face.
  hand,
}

/// A text placed on the photo.
@freezed
abstract class TextItem with _$TextItem {
  /// Creates a text.
  const factory TextItem({
    required String text,

    /// Center, in fractions of the rotated photo (like the crop).
    required double x,
    required double y,

    /// Letter height, as a fraction of the photo's shorter side.
    @Default(0.06) double size,

    /// Color as 0xAARRGGBB.
    @Default(0xFFFFFFFF) int color,

    /// Box color behind the text as 0xAARRGGBB, or `null` for none.
    int? background,
    @Default(TextFont.sans) TextFont font,
    @Default(false) bool bold,
  }) = _TextItem;

  const TextItem._();

  /// The same text once the photo is turned a quarter clockwise: it moves
  /// with the photo and stays upright.
  TextItem rotatedClockwise() => copyWith(x: 1 - y, y: x);

  /// The same text once the photo is mirrored: it moves, still readable.
  TextItem flipped() => copyWith(x: 1 - x);
}

/// Scale that makes a photo of [ratio] (width / height) turned by
/// [degrees] cover its own frame, so straightening leaves no empty corner.
double straightenScale(double degrees, double ratio) {
  if (degrees == 0) return 1;
  final a = degrees.abs() * math.pi / 180;
  final c = math.cos(a);
  final s = math.sin(a);
  return math.max(c + s / ratio, c + s * ratio);
}

/// Everything the editor changes in a photo, as plain data: applied in this
/// order, rotation, flip, colors, drawing, then the crop (in the rotated and
/// flipped photo). The original is never changed; saving writes a new
/// photo.
@freezed
abstract class PhotoEdit with _$PhotoEdit {
  /// Creates an edit.
  const factory PhotoEdit({
    /// Quarter turns clockwise, 0 to 3.
    @Default(0) int quarterTurns,

    /// Mirrored left to right, after the rotation.
    @Default(false) bool flipped,

    /// Area kept, in the rotated and flipped photo.
    @Default(CropRect.full) CropRect crop,

    /// Color adjustments.
    @Default(Adjustments()) Adjustments adjustments,

    /// Lines drawn with the pencil, oldest first.
    @Default(<Stroke>[]) List<Stroke> strokes,

    /// Fine rotation in degrees, -45 to 45, clockwise, to straighten a
    /// horizon; the photo is enlarged so that no corner is empty.
    @Default(0) double angle,

    /// Texts, drawn last.
    @Default(<TextItem>[]) List<TextItem> texts,
  }) = _PhotoEdit;

  const PhotoEdit._();

  /// Whether the edit changes nothing.
  bool get isIdentity =>
      quarterTurns == 0 &&
      !flipped &&
      crop.isFull &&
      adjustments.isNeutral &&
      strokes.isEmpty &&
      angle == 0 &&
      texts.isEmpty;

  /// Turned a quarter clockwise; the crop and the drawing turn with the
  /// photo.
  PhotoEdit rotated() => copyWith(
    quarterTurns: (quarterTurns + 1) % 4,
    crop: crop.rotatedClockwise(),
    strokes: [for (final s in strokes) s.rotatedClockwise()],
    texts: [for (final t in texts) t.rotatedClockwise()],
  );

  /// Mirrored left to right; the crop and the drawing are mirrored with
  /// the photo.
  PhotoEdit mirrored() => copyWith(
    flipped: !flipped,
    crop: crop.flipped(),
    strokes: [for (final s in strokes) s.flipped()],
    texts: [for (final t in texts) t.flipped()],
    angle: -angle,
  );

  /// Width divided by height of a photo of [width] × [height] pixels once
  /// rotated.
  double orientedRatio(int width, int height) {
    if (width <= 0 || height <= 0) return 1;
    return quarterTurns.isOdd ? height / width : width / height;
  }
}
