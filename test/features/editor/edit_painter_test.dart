import 'dart:ui' as ui;

import 'package:clean_gallery/domain/photo_edit.dart';
import 'package:clean_gallery/features/editor/edit_painter.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const line = Stroke(
    points: [(0.2, 0.5), (0.8, 0.5)],
    color: 0xFFFFFFFF,
    width: 0.1,
  );

  test('a line covers its points, the band between them, nothing more', () {
    final area = strokeArea(line, const Size(100, 100));
    expect(area.contains(const Offset(50, 50)), isTrue);
    expect(area.contains(const Offset(50, 54)), isTrue);
    // Where a disc and the band overlap: still inside, not a hole.
    expect(area.contains(const Offset(21, 52)), isTrue);
    expect(area.contains(const Offset(79, 48)), isTrue);
    // A round end.
    expect(area.contains(const Offset(16, 50)), isTrue);
    expect(area.contains(const Offset(50, 60)), isFalse);
    expect(area.contains(const Offset(5, 50)), isFalse);
  });

  testWidgets('blur and pixelate change only the area under the line', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // A 100 × 100 checkerboard of single black and white pixels.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..drawRect(
          const Rect.fromLTWH(0, 0, 100, 100),
          Paint()..color = const Color(0xFFFFFFFF),
        );
      final black = Paint()..color = const Color(0xFF000000);
      for (var y = 0; y < 100; y++) {
        for (var x = y % 2; x < 100; x += 2) {
          canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
            black,
          );
        }
      }
      final picture = recorder.endRecording();
      final source = EditSource(await picture.toImage(100, 100));
      picture.dispose();

      for (final kind in [StrokeKind.pixelate, StrokeKind.blur]) {
        final rendered = await renderEdit(
          source,
          PhotoEdit(strokes: [line.copyWith(kind: kind)]),
        );
        final pixels = (await rendered.toByteData())!.buffer.asUint8List();
        int red(int x, int y) => pixels[(y * 100 + x) * 4];
        // Far from the line: the checkerboard as it was.
        expect(red(50, 10), anyOf(0, 255), reason: '$kind, far away');
        expect(red(50, 90), isNot(red(51, 90)), reason: '$kind, far away');
        // Under the line: blurred or averaged, neither black nor white.
        expect(red(50, 50), inInclusiveRange(30, 225), reason: '$kind, under');
        rendered.dispose();
      }
      source.dispose();
    });
  });
}
