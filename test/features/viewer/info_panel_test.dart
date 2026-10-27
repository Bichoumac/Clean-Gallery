import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/domain/media_metadata.dart';
import 'package:clean_gallery/features/viewer/info_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  Future<void> openInfo(
    WidgetTester tester,
    FakeMediaSource media, {
    FakePermissionService? permissions,
    FakePlatformBridge? bridge,
  }) async {
    await pumpTestApp(
      tester,
      media: media,
      permissions: permissions,
      bridge: bridge,
    );
    await tester.tap(find.byType(MediaThumbnail).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Details'));
    await tester.pumpAndSettle();
    expect(find.byType(InfoPanel), findsOneWidget);
  }

  testApp('shows the file, the camera settings and the location', (
    tester,
  ) async {
    final bridge = FakePlatformBridge();
    final media = FakeMediaSource(items: [testItem(1, sizeBytes: 3 << 20)])
      ..metadatas['1'] = const MediaMetadata(
        make: 'samsung',
        model: 'Galaxy A54 5G',
        iso: 100,
        aperture: 1.8,
        exposure: 0.008,
        focalLength: 5.4,
        focalLength35: 24,
        latitude: 48.856613,
        longitude: 2.352222,
      );
    await openInfo(tester, media, bridge: bridge);

    expect(find.text("From the photo's metadata (EXIF)"), findsOneWidget);
    expect(find.text('IMG_1.jpg'), findsWidgets);
    expect(find.text('DCIM/Camera/'), findsOneWidget);
    expect(find.text('3.0 MB'), findsOneWidget);
    expect(find.text('samsung Galaxy A54 5G'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('f/1.8'), findsOneWidget);
    expect(find.text('1/125 s'), findsOneWidget);
    expect(find.text('5.4 mm · 24 mm equivalent'), findsOneWidget);
    expect(find.text('Location · tap to open in a map app'), findsOneWidget);

    // The end of the panel can be reached, and the location opens a map.
    await tester.ensureVisible(find.text('48.85661, 2.35222'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('48.85661, 2.35222'));
    await tester.pumpAndSettle();
    expect(bridge.mapRequests, [(48.856613, 2.352222)]);
  });

  testApp('says what is missing', (tester) async {
    final media = FakeMediaSource(items: [testItem(1)])
      ..withoutMetadataDate.add('1');
    await openInfo(
      tester,
      media,
      permissions: FakePermissionService()..locationGranted = false,
    );

    expect(find.text('No camera information in this file.'), findsOneWidget);
    expect(
      find.text('Allow location access in Settings to see where it was taken.'),
      findsOneWidget,
    );
  });

  test('formats camera settings', () {
    expect(formatAperture(2, 'en'), 'f/2');
    expect(formatAperture(1.8, 'fr'), 'f/1,8');
    expect(formatShutter(1 / 60, 'en'), '1/60 s');
    expect(formatShutter(2, 'en'), '2 s');
    expect(formatShutter(1.5, 'en'), '1.5 s');
    expect(formatCoordinates(-33.8688, 151.2093), '-33.86880, 151.20930');
  });

  test('names the camera once', () {
    expect(
      const MediaMetadata(make: 'Canon', model: 'Canon EOS R6').camera,
      'Canon EOS R6',
    );
    expect(const MediaMetadata(make: 'samsung').camera, 'samsung');
    expect(MediaMetadata.empty.camera, isNull);
  });
}
