import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/features/library/albums_screen.dart';
import 'package:clean_gallery/features/library/media_timeline_view.dart';
import 'package:clean_gallery/features/viewer/viewer_screen.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();
  final library = [
    testItem(1, takenAt: now),
    testItem(2, takenAt: now, isFavorite: true),
    testItem(3, takenAt: now, duration: const Duration(seconds: 75)),
    testItem(4, takenAt: DateTime(2025, 1, 10, 9)),
  ];

  FakeMediaSource source() => FakeMediaSource(
    items: library,
    folders: const [Album(id: 'cam', name: 'Camera', count: 2)],
    folderItems: {
      'cam': [library[0], library[3]],
    },
  );

  testApp('Camera tab: date headers and photos only', (tester) async {
    await pumpTestApp(tester, media: source());
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Friday, January 10, 2025'), findsOneWidget);
    expect(find.byType(MediaThumbnail), findsNWidgets(3));
  });

  testApp('Videos tab: videos only, with a duration badge', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byTooltip('Videos'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaThumbnail), findsOneWidget);
    expect(find.text('1:15'), findsOneWidget);
  });

  testApp('empty library shows the empty state', (tester) async {
    await pumpTestApp(tester);
    expect(find.text('No camera photos yet'), findsOneWidget);
  });

  testApp('denied access shows a prompt that requests access', (tester) async {
    final permissions = FakePermissionService(result: MediaAccess.denied);
    await pumpTestApp(tester, media: source(), permissions: permissions);
    expect(find.text('Allow access to your media'), findsOneWidget);
    expect(find.byType(MediaThumbnail), findsNothing);

    await tester.tap(find.text('Allow access'));
    await tester.pumpAndSettle();
    expect(permissions.mediaRequests, 1);
    // Still denied: the app settings are opened.
    expect(permissions.settingsOpened, 1);
  });

  testApp('limited access shows the banner and the shared items', (
    tester,
  ) async {
    final permissions = FakePermissionService(result: MediaAccess.limited);
    await pumpTestApp(tester, media: source(), permissions: permissions);
    expect(find.text('Only some of your media is shared.'), findsOneWidget);
    expect(find.byType(MediaThumbnail), findsNWidgets(3));
  });

  testApp('Albums tab lists virtual albums and folders', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    expect(find.text('All media'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('4 items'), findsOneWidget); // All media.
    expect(find.text('1 item'), findsOneWidget); // Favorites.
    // My albums comes before the folders: scroll them up.
    await tester.drag(
      find.descendant(
        of: find.byType(AlbumsScreen),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget); // Camera.
  });

  testApp('opening a folder shows its items and a back button', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    // Folders come after All media, Favorites and Trash, and the floating
    // navigation bar covers the bottom of the screen: scroll them up.
    await tester.drag(
      find.descendant(
        of: find.byType(AlbumsScreen),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(MediaThumbnail), findsNWidgets(2));

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Folders'), findsOneWidget);
  });

  testApp('tapping a thumbnail opens the viewer on that item', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byType(MediaThumbnail).at(1));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget);
    // Same capture time as IMG_2: ordered by id, newest first.
    expect(find.text('IMG_1.jpg'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsNothing);
  });

  testApp('pinching changes the column count', (tester) async {
    await pumpTestApp(tester, media: source());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaTimelineView)),
    );
    expect(container.read(gridColumnsProvider), 4);

    final center = tester.getCenter(find.byType(MediaTimelineView));
    final a = await tester.startGesture(center - const Offset(20, 0));
    final b = await tester.startGesture(center + const Offset(20, 0));
    // Spread from 40 to 60 px (ratio 1.5): exactly one zoom-in step.
    await a.moveBy(const Offset(-10, 0));
    await b.moveBy(const Offset(10, 0));
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(container.read(gridColumnsProvider), 3);
  });

  testApp('pull-to-refresh indexes new items', (tester) async {
    final media = source();
    await pumpTestApp(tester, media: media);
    expect(find.byType(MediaThumbnail), findsNWidgets(3));

    media.items = [testItem(5, takenAt: now), ...library];
    await tester.fling(
      find.byType(MediaTimelineView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.byType(MediaThumbnail), findsNWidgets(4));
  });

  testApp('Camera tab leaves out screenshots; All media has them', (
    tester,
  ) async {
    final media = FakeMediaSource(
      items: [
        testItem(1, takenAt: now),
        testItem(
          2,
          takenAt: now.subtract(const Duration(minutes: 1)),
          relativePath: 'Pictures/Screenshots/',
        ),
      ],
    );
    await pumpTestApp(tester, media: media);
    expect(find.byType(MediaThumbnail), findsOneWidget);

    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All media'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaThumbnail), findsNWidgets(2));
  });
}
