import 'package:clean_gallery/domain/slideshow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('options round-trip through their stored text', () {
    const options = SlideshowOptions(
      photoSeconds: 8,
      transition: SlideshowTransition.crossfade,
      order: SlideshowOrder.shuffled,
      includeVideos: false,
      skipDuplicatesAndBlurry: false,
      music: SlideshowMusic.device(uri: 'content://x/1', name: 'Song.mp3'),
    );
    expect(SlideshowOptions.decode(options.encode()), options);
    const bundled = SlideshowOptions(music: SlideshowMusic.bundled('calm'));
    expect(SlideshowOptions.decode(bundled.encode()), bundled);
  });

  test('unreadable or invalid text gives the defaults', () {
    const defaults = SlideshowOptions();
    expect(SlideshowOptions.decode(null), defaults);
    expect(SlideshowOptions.decode('not json'), defaults);
    expect(SlideshowOptions.decode('[1]'), defaults);
    expect(
      SlideshowOptions.decode('{"seconds": 4, "transition": "spin"}'),
      defaults,
    );
  });
}
