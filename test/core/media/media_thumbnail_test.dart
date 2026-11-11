import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  test('thumbnails ask for the step covering their physical size', () {
    // Four columns on a 411 dp wide phone at 2.625: about 268 pixels.
    expect(thumbnailPixels(101, 2.625), 320);
    // Two columns: about 540 pixels, more than MediaStore's cache holds.
    expect(thumbnailPixels(205, 2.625), 640);
    expect(thumbnailPixels(128, 2), 256);
    expect(thumbnailPixels(1000, 3), thumbnailSteps.last);
  });

  testWidgets('a thumbnail without a size asks for the size of its box', (
    tester,
  ) async {
    // Issue: memory cards and album covers asked for 512 or 768 pixels
    // whatever their size, and were blurry once stretched.
    final media = FakeMediaSource();
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mediaSourceProvider.overrideWithValue(media)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 380,
              height: 220,
              child: MediaThumbnail(item: testItem(1), hero: false),
            ),
          ),
        ),
      ),
    );
    // 380 dp × 2.625 = 998 pixels.
    expect(media.thumbnailSizes.last, 1024);
  });

  group('sharp thumbnails', () {
    Future<void> pump(
      WidgetTester tester,
      FakeMediaSource media, {
      required int pixelSize,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mediaSourceProvider.overrideWithValue(media)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: SizedBox.square(
              dimension: 100,
              child: MediaThumbnail(
                item: testItem(1),
                pixelSize: pixelSize,
                hero: false,
              ),
            ),
          ),
        ),
      );
      // Images decode outside the fake clock.
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    testWidgets('a cached thumbnail too small gets its sharp version', (
      tester,
    ) async {
      // The fake's cached thumbnail is 1 pixel: too small for 256.
      final media = FakeMediaSource()
        ..sharpImage = MemoryImage(kTransparentPng);
      await pump(tester, media, pixelSize: 256);
      expect(media.sharpSizes, [256]);
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('a cached thumbnail large enough stays alone', (tester) async {
      final media = FakeMediaSource()
        ..sharpImage = MemoryImage(kTransparentPng);
      await pump(tester, media, pixelSize: 1);
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
