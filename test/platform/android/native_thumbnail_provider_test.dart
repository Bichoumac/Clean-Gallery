import 'package:clean_gallery/platform/android/android_platform_bridge.dart';
import 'package:clean_gallery/platform/android/media_image_providers.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('clean_gallery/test-thumbnails');

  setUp(() => PaintingBinding.instance.imageCache.clear());
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'a dropped request is not kept: asking again reaches the loader',
    () async {
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls++;
            throw PlatformException(code: 'dropped');
          });
      final provider = NativeThumbnailProvider(
        AndroidPlatformBridge(channel: channel),
        id: '1',
        isVideo: false,
        modifiedSecond: 1,
        width: 192,
        height: 192,
      );

      Future<void> ask() async {
        provider
            .resolve(ImageConfiguration.empty)
            .addListener(ImageStreamListener((_, _) {}, onError: (_, _) {}));
        await pumpEventQueue();
      }

      await ask();
      expect(calls, 1);
      await ask();
      expect(calls, 2, reason: 'the failure must not stay in the image cache');
    },
  );
}
