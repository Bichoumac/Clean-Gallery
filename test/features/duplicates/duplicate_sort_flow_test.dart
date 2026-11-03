import 'package:clean_gallery/core/media/duplicates_tile.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/features/library/albums_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();

  // Newest first by id. 1 and 2 are two copies (the newest group); 3, 4
  // and 5 three copies; 6 has none. Camera holds 1, 2 and 6, WhatsApp 3
  // to 5.
  final items = [
    for (var i = 1; i <= 6; i++)
      testItem(
        i,
        takenAt: now.subtract(Duration(minutes: i)),
        sizeBytes: switch (i) {
          1 || 2 => 100,
          3 || 4 || 5 => 200,
          _ => 300,
        },
      ),
  ];

  FakeMediaSource source() {
    final media = FakeMediaSource(
      items: items,
      folders: const [
        Album(id: 'cam', name: 'Camera', count: 0),
        Album(id: 'wa', name: 'WhatsApp', count: 0),
      ],
      folderItems: {
        'cam': [items[0], items[1], items[5]],
        'wa': items.sublist(2, 5),
      },
    );
    media.hashes
      ..['1'] = 'a'
      ..['2'] = 'a'
      ..['3'] = 'b'
      ..['4'] = 'b'
      ..['5'] = 'b';
    return media;
  }

  testApp('the duplicates screen can put the largest groups first', (
    tester,
  ) async {
    await pumpTestApp(tester, media: source());
    // All media: the groups of the whole library.
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All media'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DuplicatesTile));
    await tester.pumpAndSettle();
    // The button of the first group: the next ones may be off screen.
    String firstButton() =>
        tester.widget<Text>(find.textContaining('to trash').first).data!;
    // Newest first: the group of two (one to trash) is on top.
    expect(firstButton(), 'Move 1 to trash');

    await tester.tap(find.byTooltip('Sort by'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Most duplicates first'));
    await tester.pumpAndSettle();
    expect(firstButton(), 'Move 2 to trash');
  });

  testApp('a timeline sorted by duplicates puts the largest group first', (
    tester,
  ) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All media'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sort and filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Duplicates'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();

    expect(find.text('Duplicates · Most duplicates first'), findsOneWidget);
    final shown = tester
        .widgetList<MediaThumbnail>(find.byType(MediaThumbnail))
        .map((t) => t.item.id);
    expect(shown, ['3', '4', '5', '1', '2', '6']);
  });

  testApp('Albums can sort folders by duplicates', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    // My albums comes before the folders: scroll them up.
    await tester.drag(
      find.descendant(
        of: find.byType(AlbumsScreen),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sort by'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicates'));
    await tester.pumpAndSettle();

    // WhatsApp holds three copies, Camera two: WhatsApp comes first.
    expect(find.text('3 items · 3 duplicates'), findsOneWidget);
    expect(find.text('3 items · 2 duplicates'), findsOneWidget);
    Offset at(String folder) => tester.getTopLeft(
      find.descendant(
        of: find.byType(AlbumsScreen),
        matching: find.text(folder),
      ),
    );
    // Side by side, WhatsApp on the left.
    expect(at('WhatsApp').dy, at('Camera').dy);
    expect(at('WhatsApp').dx, lessThan(at('Camera').dx));
  });
}
