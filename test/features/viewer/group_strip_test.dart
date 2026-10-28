import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/features/viewer/group_strip.dart';
import 'package:clean_gallery/features/viewer/viewer_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();

  // 1 and 3 are identical copies (3, a favorite, is the best), with 2, an
  // unrelated photo, between them so they do not stack in the grid.
  FakeMediaSource source() {
    final media = FakeMediaSource(
      items: [
        testItem(1, takenAt: now, sizeBytes: 2000),
        testItem(2, takenAt: now.subtract(const Duration(minutes: 1))),
        testItem(
          3,
          takenAt: now.subtract(const Duration(minutes: 2)),
          sizeBytes: 2000,
          isFavorite: true,
        ),
      ],
    );
    media.hashes
      ..['1'] = 'same'
      ..['3'] = 'same';
    return media;
  }

  Future<void> openPhoto(WidgetTester tester, int index) async {
    await tester.tap(find.byType(MediaThumbnail).at(index));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget);
  }

  /// File name in the viewer's top bar.
  String shownName(WidgetTester tester) =>
      tester.widget<Text>(find.textContaining('IMG_').first).data!;

  testApp('a photo of a group shows the group, its best one marked', (
    tester,
  ) async {
    await pumpTestApp(tester, media: source());
    await openPhoto(tester, 0);
    expect(find.byType(GroupStrip), findsOneWidget);
    expect(find.text('2 duplicates · tap to compare'), findsOneWidget);
    expect(find.bySemanticsLabel('Best'), findsOneWidget);
  });

  testApp('a photo outside any group has no strip', (tester) async {
    await pumpTestApp(tester, media: source());
    await openPhoto(tester, 1);
    expect(find.byType(GroupStrip), findsNothing);
  });

  testApp('a thumbnail of the strip shows that photo', (tester) async {
    await pumpTestApp(tester, media: source());
    await openPhoto(tester, 0);
    expect(shownName(tester), 'IMG_1.jpg');
    await tester.tap(find.bySemanticsLabel('Best'));
    await tester.pumpAndSettle();
    expect(shownName(tester), 'IMG_3.jpg');
    expect(find.byType(GroupStrip), findsOneWidget);
  });

  testApp('Trash moves the photo to the trash and shows the next; Undo '
      'brings it back', (tester) async {
    await pumpTestApp(tester, media: source());
    await openPhoto(tester, 0);
    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
    expect(shownName(tester), 'IMG_3.jpg');
    // The trashed photo stays in the strip, dimmed.
    expect(
      find.bySemanticsLabel('in the trash, tap to restore'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(shownName(tester), 'IMG_1.jpg');
    expect(find.bySemanticsLabel('in the trash, tap to restore'), findsNothing);
  });

  testApp('Keep marks the photo and shows the next one to sort', (
    tester,
  ) async {
    await pumpTestApp(tester, media: source());
    await openPhoto(tester, 0);
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(shownName(tester), 'IMG_3.jpg');
    // The button, and now the kept thumbnail.
    expect(find.bySemanticsLabel('Keep'), findsNWidgets(2));
  });
}
