import 'package:clean_gallery/core/media/retrying_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

/// An image failing with [error] for its first [failures] loads, then
/// loading.
class _Flaky extends ImageProvider<String> {
  _Flaky({required this.error, required this.failures});

  final Object error;
  final int failures;
  int loads = 0;

  @override
  Future<String> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture('flaky-$hashCode');

  @override
  ImageStreamCompleter loadImage(String key, ImageDecoderCallback decode) {
    loads++;
    if (loads > failures) {
      final image = MemoryImage(kTransparentPng);
      return image.loadImage(image, decode);
    }
    return OneFrameImageStreamCompleter(Future<ImageInfo>.error(error));
  }
}

void main() {
  const failure = Icon(Icons.broken_image_outlined);
  final broken = find.byType(Icon);

  Future<void> pump(WidgetTester tester, ImageProvider image) =>
      tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RetryingImage(image: image, failure: failure),
        ),
      );

  testWidgets('a dropped thumbnail is asked for again until it loads', (
    tester,
  ) async {
    final image = _Flaky(
      error: PlatformException(code: 'dropped'),
      failures: 10,
    );
    await pump(tester, image);
    await tester.pump();
    expect(image.loads, 1);

    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    }
    expect(image.loads, 11, reason: 'dropped requests have no limit');
    expect(broken, findsNothing);
  });

  testWidgets('a broken file is given up on after three more tries', (
    tester,
  ) async {
    final image = _Flaky(
      error: PlatformException(code: 'not_found'),
      failures: 100,
    );
    await pump(tester, image);
    await tester.pump();
    expect(broken, findsNothing);

    for (final seconds in [1, 2, 3]) {
      await tester.pump(Duration(seconds: seconds));
      await tester.pump();
    }
    expect(image.loads, 4);
    expect(broken, findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(image.loads, 4);
  });

  testWidgets('no retry fires once the image has left the screen', (
    tester,
  ) async {
    final image = _Flaky(
      error: PlatformException(code: 'dropped'),
      failures: 100,
    );
    await pump(tester, image);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(image.loads, 1);
  });
}
