import 'package:clean_gallery/analysis/screenshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screen = (width: 1080, height: 2340);

  bool check(
    String path,
    String name, {
    String mime = 'image/jpeg',
    int width = 4000,
    int height = 3000,
  }) => isScreenshot(
    relativePath: path,
    fileName: name,
    mimeType: mime,
    width: width,
    height: height,
    screen: screen,
  );

  test('a photo in a Screenshots folder', () {
    expect(check('DCIM/Screenshots/', 'IMG_1.jpg'), isTrue);
    expect(check('Pictures/Screenshots/', 'a.png'), isTrue);
    expect(check('Pictures/screenshots/', 'a.png'), isTrue);
  });

  test('a file named like a screenshot', () {
    expect(check('Download/', 'Screenshot_20240315-142233_Chrome.jpg'), isTrue);
    expect(check('Download/', 'Screenshot 2024-03-15 at 14.22.33.png'), isTrue);
    expect(check('Download/', 'screen_shot.png'), isTrue);
  });

  test('a PNG the size of the screen, in either orientation', () {
    expect(
      check(
        'Pictures/App/',
        'a.png',
        mime: 'image/png',
        width: 1080,
        height: 2340,
      ),
      isTrue,
    );
    expect(
      check(
        'Pictures/App/',
        'a.png',
        mime: 'image/png',
        width: 2340,
        height: 1080,
      ),
      isTrue,
    );
  });

  test('camera photos and other images are not screenshots', () {
    expect(check('DCIM/Camera/', '20240315_142233.jpg'), isFalse);
    expect(check('Pictures/Screenshots backup old/', 'a.jpg'), isFalse);
    expect(check('Download/', 'my_screenshot.png'), isFalse);
    // A JPEG the size of the screen: a wallpaper or a received picture.
    expect(check('Download/', 'a.jpg', width: 1080, height: 2340), isFalse);
    expect(
      check('Download/', 'a.png', mime: 'image/png', width: 1080, height: 2000),
      isFalse,
    );
  });

  test('without a known screen size, only the folder and name count', () {
    expect(
      isScreenshot(
        relativePath: 'Pictures/App/',
        fileName: 'a.png',
        mimeType: 'image/png',
        width: 1080,
        height: 2340,
      ),
      isFalse,
    );
  });
}
