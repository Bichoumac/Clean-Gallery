import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/media_metadata.dart';
import 'package:clean_gallery/features/map/map_area_screen.dart';
import 'package:clean_gallery/features/map/map_screen.dart';
import 'package:clean_gallery/features/map/mini_map.dart';
import 'package:clean_gallery/features/viewer/viewer_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();

  // Two photos in Paris, 300 m apart, one in Lyon and one without a place.
  FakeMediaSource source() {
    final media = FakeMediaSource(
      items: [
        for (var i = 1; i <= 4; i++)
          testItem(i, takenAt: now.subtract(Duration(minutes: i))),
      ],
    );
    media.positions
      ..['1'] = (latitude: 48.8584, longitude: 2.2945)
      ..['2'] = (latitude: 48.8606, longitude: 2.2976)
      ..['3'] = (latitude: 45.7640, longitude: 4.8357);
    return media;
  }

  Future<void> openMap(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
  }

  testApp('Albums shows the map tile with the located items', (tester) async {
    await pumpTestApp(tester, media: source());
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
  });

  testApp('the map clusters nearby photos; a cluster opens its grid', (
    tester,
  ) async {
    await pumpTestApp(tester, media: source());
    await openMap(tester);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(find.bySemanticsLabel('2 items here'), findsOneWidget);
    expect(find.bySemanticsLabel('1 item here'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('2 items here'));
    await tester.pumpAndSettle();
    expect(find.byType(MapAreaScreen), findsOneWidget);
    expect(find.text('In this area'), findsOneWidget);
    final shown = tester
        .widgetList<MediaThumbnail>(find.byType(MediaThumbnail))
        .map((t) => t.item.id);
    expect(shown, ['1', '2']);
  });

  testApp('the analysis waits while the map is open', (tester) async {
    await pumpTestApp(tester, media: source());
    await openMap(tester);
    final scan = ProviderScope.containerOf(
      tester.element(find.byType(MapScreen)),
    ).read(duplicateScanProvider.notifier);
    expect(scan.paused, isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(scan.paused, isFalse);
  });

  testApp('a marker asks again for a thumbnail that failed, then gives up', (
    tester,
  ) async {
    final media = _FailingThumbnails(items: [testItem(1, takenAt: now)]);
    media.positions['1'] = (latitude: 48.8584, longitude: 2.2945);
    await pumpTestApp(tester, media: media);
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    media.markerLoads = 0;
    media.failing = true;
    PaintingBinding.instance.imageCache.clear();
    await openMap(tester);
    final first = media.markerLoads;
    expect(first, greaterThan(0));
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);

    // 1, 2 and 3 s apart.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(media.markerLoads, greaterThan(first));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    final last = media.markerLoads;
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    expect(media.markerLoads, last);
  });

  testApp('a single photo opens the viewer', (tester) async {
    await pumpTestApp(tester, media: source());
    await openMap(tester);
    await tester.tap(find.bySemanticsLabel('1 item here'));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget);
  });

  testApp('without the location permission, the map asks for it', (
    tester,
  ) async {
    final permissions = FakePermissionService()..locationGranted = false;
    await pumpTestApp(tester, media: source(), permissions: permissions);
    await openMap(tester);
    expect(find.text('Allow access to photo locations'), findsOneWidget);
    expect(find.bySemanticsLabel('1 item here'), findsNothing);

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(permissions.locationRequests, 1);
    expect(find.text('Allow access to photo locations'), findsNothing);
    // The map opened on the whole world: France is one cluster.
    expect(find.bySemanticsLabel('3 items here'), findsOneWidget);
  });

  testApp('no located photo: the map says so', (tester) async {
    await pumpTestApp(
      tester,
      media: FakeMediaSource(items: [testItem(1, takenAt: now)]),
    );
    await openMap(tester);
    expect(find.text('No places yet'), findsOneWidget);
  });

  testApp('the info panel mini map opens the map there', (tester) async {
    final media = source()
      ..metadatas['1'] = const MediaMetadata(
        latitude: 48.8584,
        longitude: 2.2945,
      );
    await pumpTestApp(tester, media: media);
    await tester.tap(find.byType(MediaThumbnail).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Details'));
    await tester.pumpAndSettle();
    expect(find.byType(MiniMap), findsOneWidget);

    await tester.ensureVisible(find.byType(MiniMap));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MiniMap));
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}

/// A source whose thumbnails can fail, counting the attempts.
class _FailingThumbnails extends FakeMediaSource {
  _FailingThumbnails({required super.items});

  bool failing = false;
  int markerLoads = 0;

  @override
  ImageProvider thumbnail(MediaItem item, {required int size}) => failing
      ? _FailingImage(() => markerLoads++, '${item.id}-$size')
      : super.thumbnail(item, size: size);
}

/// An image that always fails to load.
class _FailingImage extends ImageProvider<String> {
  const _FailingImage(this.onLoad, this.id);

  final VoidCallback onLoad;
  final String id;

  @override
  Future<String> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture('failing-$id');

  @override
  ImageStreamCompleter loadImage(String key, ImageDecoderCallback decode) {
    onLoad();
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(StateError('no thumbnail')),
    );
  }
}
