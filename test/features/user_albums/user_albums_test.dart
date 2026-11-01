import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/features/user_albums/user_album_screen.dart';
import 'package:clean_gallery/features/viewer/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();
  // Four camera photos of today, newest first.
  FakeMediaSource source() => FakeMediaSource(
    items: [
      for (var i = 1; i <= 4; i++)
        testItem(i, takenAt: now.subtract(Duration(minutes: i))),
    ],
  );

  List<String> shownIds(WidgetTester tester) => [
    for (final t in tester.widgetList<MediaThumbnail>(
      find.descendant(
        of: find.byType(UserAlbumScreen),
        matching: find.byType(MediaThumbnail),
      ),
    ))
      t.item.id,
  ];

  Future<void> openAlbumsTab(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
  }

  /// Scrolls the Albums tab to its end, *My albums* clear of the
  /// navigation bar.
  Future<void> scrollToMyAlbums(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
    await tester.pumpAndSettle();
  }

  /// Taps the *New album* tile of the Albums tab.
  Future<void> tapNewAlbumTile(WidgetTester tester) async {
    await scrollToMyAlbums(tester);
    await tester.tap(find.bySemanticsLabel('New album'));
    await tester.pumpAndSettle();
  }

  /// Closes the snackbar shown last, uncovering the bottom bar (with an
  /// action, it stays until closed).
  Future<void> closeSnackBar(WidgetTester tester) async {
    ScaffoldMessenger.of(tester.element(find.byType(SnackBar)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
  }

  Future<void> typeName(WidgetTester tester, String name, String button) async {
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.widgetWithText(FilledButton, button));
    await tester.pumpAndSettle();
  }

  /// Selects the Camera photos at [indexes] and adds them to an album
  /// through the selection bar's More menu.
  Future<void> addSelection(WidgetTester tester, List<int> indexes) async {
    final thumbs = find.byType(MediaThumbnail);
    await tester.longPress(thumbs.at(indexes.first));
    await tester.pumpAndSettle();
    for (final i in indexes.skip(1)) {
      await tester.tap(thumbs.at(i));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to album'));
    await tester.pumpAndSettle();
  }

  testApp('an empty Albums tab offers a new album, explained', (tester) async {
    await pumpTestApp(tester, media: source());
    await openAlbumsTab(tester);
    await scrollToMyAlbums(tester);
    expect(find.text('My albums'), findsOneWidget);
    expect(find.textContaining('without moving them'), findsOneWidget);

    await tapNewAlbumTile(tester);
    // An empty name is refused.
    await typeName(tester, '  ', 'Create');
    expect(find.text('Enter a name'), findsOneWidget);
    await typeName(tester, 'Holidays', 'Create');

    expect(find.byType(UserAlbumScreen), findsOneWidget);
    expect(find.text('Holidays'), findsOneWidget);
    expect(find.textContaining('Nothing is moved or copied'), findsOneWidget);
  });

  testApp('add a selection to a new album, then open it', (tester) async {
    await pumpTestApp(tester, media: source());
    await addSelection(tester, [0, 2]);
    expect(find.text('Add 2 items to an album'), findsOneWidget);
    await tester.tap(find.text('New album'));
    await tester.pumpAndSettle();
    await typeName(tester, 'Trip', 'Create');
    expect(find.text('2 items added to Trip'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(UserAlbumScreen), findsOneWidget);
    expect(shownIds(tester), ['1', '3']);
  });

  testApp('items already in the album are said so', (tester) async {
    await pumpTestApp(tester, media: source());
    await addSelection(tester, [0]);
    await tester.tap(find.text('New album'));
    await tester.pumpAndSettle();
    await typeName(tester, 'Trip', 'Create');
    await closeSnackBar(tester);

    await addSelection(tester, [0]);
    expect(find.text('Already in it'), findsOneWidget);
    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();
    expect(find.text('Already in Trip'), findsOneWidget);
    await closeSnackBar(tester);

    // Two items, one already in: only the other is added.
    await addSelection(tester, [0, 1]);
    expect(find.text('1 already in it'), findsOneWidget);
    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();
    expect(find.text('Added to Trip'), findsOneWidget);
  });

  testApp('the viewer adds its photo to an album', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byType(MediaThumbnail).first);
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Add to album'));
    await tester.pumpAndSettle();
    expect(find.text('Add 1 item to an album'), findsOneWidget);
    await tester.tap(find.text('New album'));
    await tester.pumpAndSettle();
    await typeName(tester, 'Best', 'Create');
    expect(find.text('Added to Best'), findsOneWidget);
  });

  /// Creates album "Trip" with the photos 1, 2 and 3 and opens it.
  Future<void> openTrip(WidgetTester tester) async {
    await pumpTestApp(tester, media: source());
    await addSelection(tester, [0, 1, 2]);
    await tester.tap(find.text('New album'));
    await tester.pumpAndSettle();
    await typeName(tester, 'Trip', 'Create');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(shownIds(tester), ['1', '2', '3']);
  }

  testApp('remove from the album, then undo', (tester) async {
    await openTrip(tester);
    final thumbs = find.descendant(
      of: find.byType(UserAlbumScreen),
      matching: find.byType(MediaThumbnail),
    );
    await tester.longPress(thumbs.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Use as cover'), findsOneWidget);
    await tester.tap(find.text('Remove from album'));
    await tester.pumpAndSettle();
    expect(find.text('Removed from the album'), findsOneWidget);
    expect(shownIds(tester), ['1', '3']);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(shownIds(tester), ['1', '2', '3']);
  });

  testApp('rename; a name in use is refused', (tester) async {
    await openTrip(tester);
    await tester.tap(find.byTooltip('Album options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await typeName(tester, 'Summer 2026', 'Rename');
    expect(find.text('Summer 2026'), findsOneWidget);

    // A second album cannot take that name, whatever the case.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openAlbumsTab(tester);
    await tapNewAlbumTile(tester);
    await typeName(tester, 'summer 2026', 'Create');
    expect(find.text('An album already has this name'), findsOneWidget);
  });

  testApp('delete the album: the photos stay; undo brings it back', (
    tester,
  ) async {
    await openTrip(tester);
    await tester.tap(find.byTooltip('Album options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete album'));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Trip”?'), findsOneWidget);
    expect(find.textContaining('its 3 items stay on your device'), findsOne);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(UserAlbumScreen), findsNothing);
    expect(find.textContaining('Album deleted'), findsOneWidget);
    // Still every photo in Camera.
    expect(find.byType(MediaThumbnail), findsNWidgets(4));

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await openAlbumsTab(tester);
    await scrollToMyAlbums(tester);
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
  });
}
