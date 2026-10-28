import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/domain/photo_edit.dart';
import 'package:clean_gallery/features/editor/editor_screen.dart';
import 'package:clean_gallery/features/editor/photo_editor.dart';
import 'package:clean_gallery/features/viewer/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();

  FakeMediaSource source() => FakeMediaSource(
    items: [
      testItem(1, takenAt: now),
      testItem(
        2,
        takenAt: now.subtract(const Duration(minutes: 1)),
        duration: const Duration(seconds: 5),
      ),
    ],
  );

  /// Opens the editor on photo 1 and waits for its preview to decode.
  Future<void> openEditor(
    WidgetTester tester, {
    FakeMediaSource? media,
    FakePlatformBridge? bridge,
  }) async {
    await pumpTestApp(tester, media: media ?? source(), bridge: bridge);
    await tester.tap(find.byType(MediaThumbnail).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    // Not pumpAndSettle: the spinner turns until the preview decodes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(EditorScreen), findsOneWidget);
    // The image decodes outside the fake clock.
    final loading = find.descendant(
      of: find.byType(EditorScreen),
      matching: find.byType(CircularProgressIndicator),
    );
    for (var i = 0; i < 50 && loading.evaluate().isNotEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(loading, findsNothing);
  }

  PhotoEditorState editorState(WidgetTester tester) {
    final screen = find.byType(EditorScreen);
    return ProviderScope.containerOf(tester.element(screen))
        .read(photoEditorProvider(tester.widget<EditorScreen>(screen).photo));
  }

  testApp('the viewer opens the editor on photos only', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byTooltip('Videos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnail).first);
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget);
    expect(find.byTooltip('Edit'), findsNothing);
  });

  testApp('rotate turns the photo; close without changes asks nothing', (
    tester,
  ) async {
    await openEditor(tester);
    await tester.tap(find.text('Rotate'));
    await tester.pumpAndSettle();
    expect(editorState(tester).edit.quarterTurns, 1);

    await tester.tap(find.byTooltip('Reset'));
    await tester.pumpAndSettle();
    expect(editorState(tester).edit.isIdentity, isTrue);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsNothing);
    expect(find.byType(ViewerScreen), findsOneWidget);
  });

  testApp('a slider adjusts; closing with changes asks first', (tester) async {
    await openEditor(tester);
    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(editorState(tester).edit.adjustments.brightness, greaterThan(0));
    expect(find.text('Brightness •'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsNothing);
  });

  testApp('a fixed shape gives a crop of that shape', (tester) async {
    await openEditor(tester);
    await tester.tap(find.text('1:1'));
    await tester.pumpAndSettle();
    final state = editorState(tester);
    expect(state.ratio, CropRatio.square);
    // testItem photos are 4000 × 3000: a square is 3/4 of the width.
    expect(state.edit.crop.width, closeTo(0.75, 1e-9));
    expect(state.edit.crop.height, closeTo(1, 1e-9));
  });

  testApp('dragging a corner of the crop shrinks it', (tester) async {
    await openEditor(tester);
    final box = tester.getRect(find.bySemanticsLabel(RegExp('Crop area')));
    await tester.dragFrom(
      box.bottomRight - const Offset(4, 4),
      const Offset(-60, -40),
    );
    await tester.pumpAndSettle();
    final crop = editorState(tester).edit.crop;
    expect(crop.right, lessThan(1));
    expect(crop.bottom, lessThan(1));
    expect(crop.left, 0);
  });

  testApp('the pencil draws lines, undone one by one', (tester) async {
    await openEditor(tester);
    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();
    final area = find.bySemanticsLabel(RegExp('Drawing area'));
    await tester.drag(area, const Offset(80, 30));
    await tester.drag(area, const Offset(-40, 60));
    await tester.pumpAndSettle();
    final strokes = editorState(tester).edit.strokes;
    expect(strokes, hasLength(2));
    expect(strokes.first.points.length, greaterThan(1));

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(editorState(tester).edit.strokes, hasLength(1));
  });

  testApp('Save as a copy saves the edit and shows the new photo', (
    tester,
  ) async {
    final media = source();
    final bridge = FakePlatformBridge()
      ..onSaveEdit = (photo) {
        media.items = [testItem(9, takenAt: photo.takenAt), ...media.items];
        return '9';
      };
    await openEditor(tester, media: media, bridge: bridge);
    await tester.tap(find.text('Rotate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save as a copy'));
    await tester.pumpAndSettle();

    expect(bridge.savedEdits.single.$1, '1');
    expect(bridge.savedEdits.single.$2.quarterTurns, 1);
    expect(find.byType(EditorScreen), findsNothing);
    expect(find.text('Copy saved'), findsOneWidget);
    expect(find.text('IMG_9.jpg'), findsOneWidget);
  });

  testApp('Replace the original moves it to the trash', (tester) async {
    final media = source();
    final bridge = FakePlatformBridge()
      ..onSaveEdit = (photo) {
        media.items = [testItem(9, takenAt: photo.takenAt), ...media.items];
        return '9';
      };
    await openEditor(tester, media: media, bridge: bridge);
    await tester.tap(find.text('Flip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace the original'));
    await tester.pumpAndSettle();

    expect(
      find.text('Photo replaced; the original is in the trash'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    final shown = tester
        .widgetList<MediaThumbnail>(find.byType(MediaThumbnail))
        .map((t) => t.item.id);
    expect(shown, ['9']);
  });
}
