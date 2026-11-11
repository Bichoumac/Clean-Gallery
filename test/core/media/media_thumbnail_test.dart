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
}
