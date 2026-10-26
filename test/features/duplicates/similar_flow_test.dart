import 'package:clean_gallery/core/media/duplicates_tile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../analysis/photo_set.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();

  // 1 and 2 are the same scene saved at two sizes (not identical files); 3
  // is another photo.
  FakeMediaSource source() {
    final beach = PhotoSet.scene(1);
    return FakeMediaSource(
        items: [
          testItem(1, takenAt: now, sizeBytes: 3000000),
          testItem(2, takenAt: now, sizeBytes: 1000000),
          testItem(3, takenAt: now, sizeBytes: 2000000),
        ],
      )
      ..grayImages.addAll({
        '1': PhotoSet.thumbnail(beach),
        '2': PhotoSet.thumbnail(PhotoSet.resized(beach, 0.5)),
        '3': PhotoSet.thumbnail(PhotoSet.scene(2)),
      });
  }

  testApp('similar photos have their own section', (tester) async {
    await pumpTestApp(tester, media: source());
    expect(find.textContaining('1 item to review'), findsOneWidget);

    await tester.tap(find.byType(DuplicatesTile));
    await tester.pumpAndSettle();
    expect(find.text('Similar photos'), findsOneWidget);
    expect(find.text('Certain duplicates'), findsNothing);
    expect(find.text('Best'), findsOneWidget);
    expect(find.text('Not duplicates'), findsOneWidget);
    // The larger file is kept, the other one picked.
    expect(find.text('Move 1 to trash'), findsOneWidget);
  });

  testApp('"Not duplicates" removes the group', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byType(DuplicatesTile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not duplicates'));
    await tester.pumpAndSettle();
    expect(find.text('Similar photos'), findsNothing);
    expect(find.text('No duplicates'), findsOneWidget);
    expect(find.text("These photos won't be grouped again."), findsOneWidget);
  });

  testApp('the Stats tab shows what cleaning could free', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byTooltip('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Space you could free'), findsOneWidget);
    expect(find.textContaining('used by your photos and videos'), findsOne);
    // The smaller copy, 1 MB, is the one to clean.
    expect(find.text('1 item'), findsOneWidget);

    await tester.tap(find.text('Similar photos'));
    await tester.pumpAndSettle();
    expect(find.text('Not duplicates'), findsOneWidget);
  });
}
