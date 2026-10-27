import 'dart:typed_data';

import 'package:clean_gallery/analysis/image_quality.dart';
import 'package:clean_gallery/domain/gray_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'photo_set.dart';

void main() {
  ImageQuality measure(PhotoMaker make) =>
      imageQuality(PhotoSet.thumbnail(make(PhotoSet.scene(3))));

  test('sharp photos, recompressed or not, are not poor quality', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      final scene = PhotoSet.scene(seed);
      for (final photo in [scene, PhotoSet.recompressed(scene)]) {
        final quality = imageQuality(PhotoSet.thumbnail(photo));
        expect(quality.sharpness, greaterThan(blurryBelow), reason: '$seed');
        expect(isPoorQuality(quality), isFalse, reason: '$seed');
      }
    }
  });

  test('out of focus photos are blurry', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      final quality = imageQuality(
        PhotoSet.thumbnail(PhotoSet.blurred(PhotoSet.scene(seed), 3)),
      );
      expect(quality.sharpness, lessThan(blurryBelow), reason: '$seed');
      expect(isPoorQuality(quality), isTrue, reason: '$seed');
    }
  });

  test('hazy photos are not blurry, unless they are out of focus too', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      final scene = PhotoSet.scene(seed);
      final hazy = imageQuality(PhotoSet.thumbnail(PhotoSet.hazed(scene, 0.2)));
      // Faint edges, as low as a blurred photo's, but sharp for the
      // contrast that is left.
      expect(hazy.sharpness, lessThan(blurryBelow), reason: '$seed');
      expect(hazy.contrast, lessThan(10), reason: '$seed');
      expect(
        relativeSharpness(sharpness: hazy.sharpness, contrast: hazy.contrast),
        greaterThanOrEqualTo(hazyFrom),
        reason: '$seed',
      );
      expect(isPoorQuality(hazy), isFalse, reason: '$seed');

      final both = imageQuality(
        PhotoSet.thumbnail(PhotoSet.hazed(PhotoSet.blurred(scene, 3), 0.2)),
      );
      expect(isPoorQuality(both), isTrue, reason: '$seed');
    }
  });

  test('without a contrast, the sharpness alone decides', () {
    expect(isBlurry(sharpness: 12), isTrue);
    expect(isBlurry(sharpness: 12, contrast: 5), isFalse);
    expect(isBlurry(sharpness: 12, contrast: 30), isTrue);
    expect(isBlurry(sharpness: 40, contrast: 30), isFalse);
    expect(isBlurry(sharpness: 0, contrast: 0), isTrue);
  });

  test('blur lowers the sharpness', () {
    final sharp = measure((p) => p);
    final soft = measure((p) => PhotoSet.blurred(p, 1));
    final blurred = measure((p) => PhotoSet.blurred(p, 3));
    expect(sharp.sharpness, greaterThan(soft.sharpness));
    expect(soft.sharpness, greaterThan(blurred.sharpness));
  });

  test('a very dark photo is poor quality, a dim one is not', () {
    final dark = measure((p) => PhotoSet.darkened(p, 0.05));
    expect(dark.brightness, lessThan(darkBelow));
    expect(isPoorQuality(dark), isTrue);
    final dim = measure((p) => PhotoSet.darkened(p, 0.4));
    expect(dim.brightness, greaterThan(darkBelow));
  });

  test('a flat image has no sharpness, a tiny one too', () {
    final flat = GrayImage(
      width: 10,
      height: 10,
      pixels: Uint8List(100)..fillRange(0, 100, 128),
    );
    expect(imageQuality(flat), (
      sharpness: 0.0,
      brightness: 128.0,
      contrast: 0.0,
    ));
    final tiny = GrayImage(width: 2, height: 1, pixels: Uint8List(2));
    expect(imageQuality(tiny).sharpness, 0);
  });
}

/// A change made to a test photo.
typedef PhotoMaker = img.Image Function(img.Image photo);
