import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/features/library/albums_screen.dart';
import 'package:clean_gallery/features/map/map_screen.dart';
import 'package:clean_gallery/features/search/search_controller.dart';
import 'package:clean_gallery/features/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();

  // 1 and 2 in Paris, 3 a video in Lyon, 4 a favorite in a WhatsApp folder
  // without a place.
  FakeMediaSource source() {
    final items = [
      testItem(
        1,
        takenAt: now.subtract(const Duration(minutes: 1)),
      ).copyWith(fileName: 'Beach_day.jpg'),
      testItem(
        2,
        takenAt: now.subtract(const Duration(minutes: 2)),
      ).copyWith(fileName: 'city.jpg'),
      testItem(
        3,
        takenAt: now.subtract(const Duration(minutes: 3)),
        duration: const Duration(seconds: 4),
      ).copyWith(fileName: 'beach.mp4'),
      testItem(
        4,
        takenAt: now.subtract(const Duration(minutes: 4)),
        isFavorite: true,
        relativePath: 'WhatsApp/Media/',
      ).copyWith(fileName: 'IMG-WA0001.jpg'),
    ];
    final media = FakeMediaSource(
      items: items,
      folders: const [Album(id: 'wa', name: 'WhatsApp Images', count: 1)],
      folderItems: {
        'wa': [items[3]],
      },
    );
    media.positions
      ..['1'] = (latitude: 48.8584, longitude: 2.2945)
      ..['2'] = (latitude: 48.8606, longitude: 2.2976)
      ..['3'] = (latitude: 45.7640, longitude: 4.8357);
    return media;
  }

  /// Opens the search from the tab [tab] (Albums: all media).
  Future<void> openSearch(WidgetTester tester, {String tab = 'Albums'}) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byTooltip(tab));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
  }

  List<String> shown(WidgetTester tester) => [
    for (final t in tester.widgetList<MediaThumbnail>(
      find.byType(MediaThumbnail),
    ))
      t.item.id,
  ];

  Future<void> typeName(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(searchTypingDelay);
    await tester.pumpAndSettle();
  }

  testApp('every tab title has a search button', (tester) async {
    await pumpTestApp(tester, media: source());
    expect(find.byTooltip('Search'), findsOneWidget);
    await tester.tap(find.byTooltip('Videos'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Search'), findsOneWidget);
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Search'), findsOneWidget);
  });

  testApp('the Camera tab searches its photos only, without type or folder', (
    tester,
  ) async {
    await openSearch(tester, tab: 'Camera');
    expect(find.text('In Camera'), findsOneWidget);
    expect(shown(tester), ['1', '2']);
    expect(find.text('Photos'), findsNothing);
    expect(find.text('Folder'), findsNothing);
    await typeName(tester, 'beach');
    expect(shown(tester), ['1']);
  });

  testApp('the Videos tab searches its videos, no type chips', (tester) async {
    await openSearch(tester, tab: 'Videos');
    expect(find.text('In Videos'), findsOneWidget);
    expect(shown(tester), ['3']);
    expect(find.text('Screenshots'), findsNothing);
    expect(find.text('Folder'), findsOneWidget);
  });

  testApp('a folder page searches that folder', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    // The folder tiles are below the fold, under the navigation bar.
    await tester.drag(
      find.descendant(
        of: find.byType(AlbumsScreen),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('WhatsApp Images'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.text('In WhatsApp Images'), findsOneWidget);
    expect(shown(tester), ['4']);
    expect(find.text('Folder'), findsNothing);
  });

  testApp('the Favorites album searches favorites, any type', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(shown(tester), ['4']);
    expect(find.widgetWithText(FilterChip, 'Favorites'), findsNothing);
    await tester.tap(find.text('Videos'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches'), findsOneWidget);
  });

  testApp('without criteria every item shows; a name narrows it', (
    tester,
  ) async {
    await openSearch(tester);
    expect(shown(tester), ['1', '2', '3', '4']);
    expect(find.text('4 items'), findsOneWidget);

    await typeName(tester, 'BEACH');
    expect(shown(tester), ['1', '3']);
    expect(find.text('2 items'), findsOneWidget);

    await typeName(tester, 'nothing');
    expect(find.text('Nothing matches'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(shown(tester), ['1', '2', '3', '4']);
  });

  testApp('type and favorites combine with the name', (tester) async {
    await openSearch(tester);
    await typeName(tester, 'beach');
    await tester.tap(find.text('Videos'));
    await tester.pumpAndSettle();
    expect(shown(tester), ['3']);

    // The type picked again: every type.
    await tester.tap(find.text('Videos'));
    await tester.pumpAndSettle();
    expect(shown(tester), ['1', '3']);

    await typeName(tester, '');
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(shown(tester), ['4']);
  });

  testApp('a period is picked among the criteria and removed', (tester) async {
    await openSearch(tester);
    await tester.tap(find.text('Dates'));
    await tester.pumpAndSettle();
    expect(find.text('Period'), findsOneWidget);
    // Every item is from today: none last year.
    await tester.tap(find.text('Last year'));
    await tester.pumpAndSettle();
    expect(find.text('Period'), findsNothing);
    expect(find.widgetWithText(InputChip, 'Last year'), findsOneWidget);
    expect(shown(tester), isEmpty);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Last year'),
        matching: find.byTooltip('Delete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dates'), findsOneWidget);
    expect(shown(tester), hasLength(4));
  });

  testApp('a folder is picked from a list and removed', (tester) async {
    await openSearch(tester);
    await tester.tap(find.text('Folder'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a folder'), findsOneWidget);
    await tester.tap(find.text('WhatsApp Images'));
    await tester.pumpAndSettle();
    expect(shown(tester), ['4']);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'WhatsApp Images'),
        matching: find.byTooltip('Delete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Folder'), findsOneWidget);
    expect(shown(tester), hasLength(4));
  });

  testApp('an area is picked on the map', (tester) async {
    await openSearch(tester);
    await tester.tap(find.text('Area'));
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.text('Choose an area'), findsOneWidget);

    // The map opens fitted to every located item.
    await tester.tap(find.text('Search this area'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Area on the map'), findsOneWidget);
    expect(shown(tester), ['1', '2', '3']);
  });

  testApp('the sort of the results stays when a criterion changes', (
    tester,
  ) async {
    await openSearch(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SearchScreen)),
    );
    MediaSelection view() => container.read(
      viewSelectionProvider(
        container.read(searchCriteriaProvider(MediaSelection.all)),
      ),
    );
    container
        .read(viewSelectionProvider(view()).notifier)
        .setSort(const MediaSort(field: MediaSortField.name));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
    expect(view().sort.field, MediaSortField.name);
    expect(view().filter, MediaFilter.photos);
    // The All media album keeps its own sort.
    expect(
      container.read(viewSelectionProvider(MediaSelection.all)).sort,
      MediaSort.newest,
    );
  });
}
