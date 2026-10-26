import 'package:clean_gallery/analysis/burst.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? id(String name) => burstIdOf(name, folder: 'DCIM/Camera/');

  test('shots of one burst share an id', () {
    for (final names in [
      [
        'IMG_20240315_142233_BURST001.jpg',
        'IMG_20240315_142233_BURST002_COVER.jpg',
      ],
      [
        '00000IMG_00000_BURST20190101123456789_COVER.jpg',
        '00001IMG_00001_BURST20190101123456789.jpg',
      ],
      ['20240315_142233_001.jpg', '20240315_142233_014.jpg'],
    ]) {
      expect(id(names[0]), isNotNull, reason: names[0]);
      expect(id(names[0]), id(names[1]), reason: names.join(' / '));
    }
  });

  test('different bursts and folders have different ids', () {
    expect(id('20240315_142233_001.jpg'), isNot(id('20240315_142234_001.jpg')));
    expect(
      burstIdOf('20240315_142233_001.jpg', folder: 'Pictures/'),
      isNot(id('20240315_142233_001.jpg')),
    );
  });

  test('ordinary names are not bursts', () {
    for (final name in [
      '20240315_142233.jpg',
      '20240315_142233(0).jpg',
      'IMG_20240315_142233.jpg',
      'IMG-20240315-WA0001.jpg',
      'Screenshot_20240315-142233_Chrome.jpg',
      'PXL_20240315_142233123.jpg',
    ]) {
      expect(id(name), isNull, reason: name);
    }
  });
}
