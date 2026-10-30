import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clean_gallery/analysis/color_matrix.dart';
import 'package:clean_gallery/domain/photo_edit.dart';
import 'package:flutter/painting.dart';

/// Squares across the shorter side of a pixelated area.
const pixelBlocks = 40;

/// Blur radius of a blurred area, as a fraction of the shorter side.
const blurSigma = 0.02;

/// A decoded photo and what the editor derives from it once.
final class EditSource {
  /// [image] and a copy reduced to [pixelBlocks] squares across its
  /// shorter side, drawn enlarged without smoothing for pixelated areas.
  factory EditSource(ui.Image image) {
    final scale = pixelBlocks / math.min(image.width, image.height);
    final width = math.max(1, (image.width * scale).round());
    final height = math.max(1, (image.height * scale).round());
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      Offset.zero & Size(width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final small = picture.toImageSync(width, height);
    picture.dispose();
    return EditSource._(image, small);
  }

  EditSource._(this.image, this.pixelated);

  /// The photo, upright.
  final ui.Image image;

  /// The photo reduced to a few squares.
  final ui.Image pixelated;

  /// Width divided by height once turned by [edit].
  double orientedRatio(PhotoEdit edit) =>
      edit.orientedRatio(image.width, image.height);

  /// Releases the images.
  void dispose() {
    image.dispose();
    pixelated.dispose();
  }
}

/// Font family of [font].
String fontFamily(TextFont font) => switch (font) {
  TextFont.sans => 'Manrope',
  TextFont.serif => 'serif',
  TextFont.mono => 'monospace',
  TextFont.hand => 'cursive',
};

/// The layout of [text] on a photo whose rotated size is [full].
TextPainter layoutText(TextItem text, Size full) {
  final shorter = math.min(full.width, full.height);
  return TextPainter(
    text: TextSpan(
      text: text.text,
      style: TextStyle(
        fontFamily: fontFamily(text.font),
        fontSize: text.size * shorter,
        fontWeight: text.bold ? FontWeight.w800 : FontWeight.w500,
        color: Color(text.color),
        height: 1.2,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: full.width * 0.9);
}

/// Area of [text] and its box on a photo whose rotated size is [full], in
/// its pixels.
Rect textBounds(TextItem text, Size full, [TextPainter? layout]) {
  final painter = layout ?? layoutText(text, full);
  final pad = text.size * math.min(full.width, full.height) * 0.3;
  return Rect.fromCenter(
    center: Offset(text.x * full.width, text.y * full.height),
    width: painter.width + 2 * pad,
    height: painter.height + 2 * pad,
  );
}

/// Paints [source] edited by [edit] into [size], showing the part [view]
/// of the rotated photo (fractions): the whole photo while cropping, the
/// crop otherwise. The editor's preview and the saved photo both come from
/// here, so what is seen is what is saved.
///
/// Order: straighten, flip and turn the photo with its colors, then the
/// blurred and pixelated areas, the vignette, the pencil lines and the
/// texts. [selectedText] gets a frame (preview only).
void paintEdit(
  Canvas canvas,
  Size size,
  EditSource source,
  PhotoEdit edit, {
  required CropRect view,
  int? selectedText,
}) {
  // The whole rotated photo, placed so that [view] fills [size].
  final full = Size(size.width / view.width, size.height / view.height);
  final shorter = math.min(full.width, full.height);
  final matrix = edit.adjustments.isNeutral && !edit.hasFilter
      ? null
      : ColorFilter.matrix(editMatrix(edit));
  canvas
    ..save()
    ..clipRect(Offset.zero & size)
    ..translate(-view.left * full.width, -view.top * full.height);

  _drawPhoto(
    canvas,
    full,
    source.image,
    edit,
    Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = matrix,
  );

  for (final stroke in edit.strokes) {
    if (stroke.kind == StrokeKind.pen) continue;
    // The photo redrawn blurred or pixelated, clipped to the line's area.
    // A clip rather than a layer masked with BlendMode.dstIn: on the
    // phone (Impeller) the mask did not apply and the whole photo was
    // blurred.
    canvas
      ..save()
      ..clipPath(strokeArea(stroke, full));
    _drawPhoto(
      canvas,
      full,
      stroke.kind == StrokeKind.blur ? source.image : source.pixelated,
      edit,
      Paint()
        ..colorFilter = matrix
        ..filterQuality = stroke.kind == StrokeKind.blur
            ? FilterQuality.medium
            : FilterQuality.none
        ..imageFilter = stroke.kind == StrokeKind.blur
            ? ui.ImageFilter.blur(
                sigmaX: blurSigma * shorter,
                sigmaY: blurSigma * shorter,
                tileMode: TileMode.clamp,
              )
            : null,
    );
    canvas.restore();
  }

  final vignette = edit.adjustments.vignette;
  if (vignette != 0) {
    // Around the crop, the photo that is kept.
    final kept = Rect.fromLTRB(
      edit.crop.left * full.width,
      edit.crop.top * full.height,
      edit.crop.right * full.width,
      edit.crop.bottom * full.height,
    );
    final edge =
        (vignette > 0 ? const Color(0xFF000000) : const Color(0xFFFFFFFF))
            .withValues(alpha: vignette.abs() * 0.85);
    canvas.drawRect(
      kept,
      Paint()
        ..shader = ui.Gradient.radial(
          kept.center,
          kept.size.longestSide * 0.72,
          [edge.withValues(alpha: 0), edge],
          [0.45, 1],
        ),
    );
  }

  for (final stroke in edit.strokes) {
    if (stroke.kind != StrokeKind.pen) continue;
    canvas.drawPath(_strokePath(stroke, full), _strokePaint(stroke, shorter));
  }

  for (final (i, text) in edit.texts.indexed) {
    final layout = layoutText(text, full);
    final box = textBounds(text, full, layout);
    final radius = Radius.circular(text.size * shorter * 0.25);
    if (text.background case final background?) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, radius),
        Paint()..color = Color(background),
      );
    }
    layout.paint(
      canvas,
      box.center - Offset(layout.width / 2, layout.height / 2),
    );
    if (i == selectedText) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(box.inflate(4), radius),
        Paint()
          ..color = const Color(0xFFC6F432)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    layout.dispose();
  }
  canvas.restore();
}

/// Draws [image] straightened, flipped and turned to fill [full].
void _drawPhoto(
  Canvas canvas,
  Size full,
  ui.Image image,
  PhotoEdit edit,
  Paint paint,
) {
  canvas
    ..save()
    ..translate(full.width / 2, full.height / 2);
  if (edit.angle != 0) {
    final scale = straightenScale(edit.angle, full.width / full.height);
    canvas
      ..rotate(edit.angle * math.pi / 180)
      ..scale(scale);
  }
  if (edit.flipped) canvas.scale(-1, 1);
  canvas.rotate(edit.quarterTurns * math.pi / 2);
  // Before turning, the photo's own width is the rotated height.
  final drawn = edit.quarterTurns.isOdd ? Size(full.height, full.width) : full;
  canvas
    ..drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(
        center: Offset.zero,
        width: drawn.width,
        height: drawn.height,
      ),
      paint,
    )
    ..restore();
}

/// The area a line of [stroke]'s width covers on a photo whose rotated
/// size is [full]: a disc at each point and a band between each two, all
/// turning the same way so that their overlaps add up.
Path strokeArea(Stroke stroke, Size full) {
  final radius = stroke.width * math.min(full.width, full.height) / 2;
  final points = [
    for (final (x, y) in stroke.points) Offset(x * full.width, y * full.height),
  ];
  final area = Path();
  for (final point in points) {
    area.addOval(Rect.fromCircle(center: point, radius: radius));
  }
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final along = b - a;
    if (along.distance == 0) continue;
    final normal = Offset(-along.dy, along.dx) / along.distance * radius;
    // Clockwise like the discs (y points down).
    area.addPolygon([a - normal, b - normal, b + normal, a + normal], true);
  }
  return area;
}

Path _strokePath(Stroke stroke, Size full) {
  final path = Path();
  for (final (i, (x, y)) in stroke.points.indexed) {
    final point = Offset(x * full.width, y * full.height);
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
    // A single tap draws a dot.
    if (stroke.points.length == 1) path.lineTo(point.dx + 0.01, point.dy);
  }
  return path;
}

Paint _strokePaint(Stroke stroke, double shorter) => Paint()
  ..color = Color(stroke.color)
  ..style = PaintingStyle.stroke
  ..strokeWidth = stroke.width * shorter
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

/// Size in pixels of [source] saved with [edit]: the crop of the rotated
/// photo.
(int, int) renderedSize(EditSource source, PhotoEdit edit) {
  final turned = edit.quarterTurns.isOdd;
  final width = (turned ? source.image.height : source.image.width).toDouble();
  final height = (turned ? source.image.width : source.image.height).toDouble();
  return (
    math.max(1, (edit.crop.width * width).round()),
    math.max(1, (edit.crop.height * height).round()),
  );
}

/// [source] with [edit] applied, at full resolution: the photo to save.
Future<ui.Image> renderEdit(EditSource source, PhotoEdit edit) {
  final (width, height) = renderedSize(source, edit);
  final recorder = ui.PictureRecorder();
  paintEdit(
    Canvas(recorder),
    Size(width.toDouble(), height.toDouble()),
    source,
    edit,
    view: edit.crop,
  );
  final picture = recorder.endRecording();
  return picture.toImage(width, height).whenComplete(picture.dispose);
}
