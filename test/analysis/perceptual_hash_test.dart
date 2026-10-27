import 'dart:typed_data';

import 'package:clean_gallery/analysis/perceptual_hash.dart';
import 'package:clean_gallery/analysis/similarity.dart';
import 'package:clean_gallery/domain/gray_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'photo_set.dart';

void main() {
  PerceptualHashes hashesOf(img.Image image) =>
      perceptualHashes(PhotoSet.thumbnail(image));

  int pDistance(img.Image a, img.Image b) =>
      hammingDistance(hashesOf(a).pHash, hashesOf(b).pHash);

  group('hammingDistance', () {
    test('counts differing bits, sign bit included', () {
      expect(hammingDistance(0, 0), 0);
      expect(hammingDistance(0, 1), 1);
      expect(hammingDistance(0, -1), 64);
      expect(hammingDistance(1 << 63, 0), 1);
      expect(hammingDistance(0x0F0F, 0x00FF), 8);
    });
  });

  group('resizeArea', () {
    test('averages the covered pixels when shrinking', () {
      final image = GrayImage(
        width: 4,
        height: 2,
        pixels: Uint8List.fromList([0, 100, 200, 200, 0, 100, 0, 0]),
      );
      expect(resizeArea(image, 2, 1), [50, 100]);
    });

    test('keeps a uniform image uniform at any size', () {
      final image = GrayImage(
        width: 7,
        height: 5,
        pixels: Uint8List(35)..fillRange(0, 35, 90),
      );
      for (final value in resizeArea(image, 32, 32)) {
        expect(value, closeTo(90, 1e-9));
      }
      for (final value in resizeArea(image, 3, 2)) {
        expect(value, closeTo(90, 1e-9));
      }
    });
  });

  group('the same photo', () {
    final original = PhotoSet.scene(1);
    final strict = SimilarityThresholds.medium.strict;

    test('gives the same hashes every time', () {
      expect(hashesOf(original), hashesOf(PhotoSet.scene(1)));
    });

    test('recompressed stays within the strict threshold', () {
      expect(
        pDistance(original, PhotoSet.recompressed(original, quality: 30)),
        lessThanOrEqualTo(strict),
      );
    });

    test('resized stays within the strict threshold', () {
      expect(
        pDistance(original, PhotoSet.resized(original, 0.4)),
        lessThanOrEqualTo(strict),
      );
      expect(
        pDistance(original, PhotoSet.resized(original, 2)),
        lessThanOrEqualTo(strict),
      );
    });

    test('brightened stays within the strict threshold', () {
      expect(
        pDistance(original, PhotoSet.brightened(original, 25)),
        lessThanOrEqualTo(strict),
      );
    });

    test('resized and recompressed (a messaging app copy) stays close', () {
      final sent = PhotoSet.recompressed(
        PhotoSet.resized(original, 0.5),
        quality: 50,
      );
      expect(pDistance(original, sent), lessThanOrEqualTo(strict));
    });

    test('slightly cropped stays within the loose threshold', () {
      expect(
        pDistance(original, PhotoSet.cropped(original, 0.03)),
        lessThanOrEqualTo(SimilarityThresholds.medium.loose),
      );
    });
  });

  group('different photos (false positive regression)', () {
    test('no two unrelated scenes are within the high strict threshold', () {
      final hashes = [
        for (var seed = 100; seed < 140; seed++)
          hashesOf(PhotoSet.scene(seed)).pHash,
      ];
      final high = SimilarityThresholds.high.strict;
      for (var i = 0; i < hashes.length; i++) {
        for (var j = i + 1; j < hashes.length; j++) {
          expect(
            hammingDistance(hashes[i], hashes[j]),
            greaterThan(high),
            reason: 'scenes ${100 + i} and ${100 + j}',
          );
        }
      }
    });

    test('unrelated scenes are far apart on average', () {
      var total = 0;
      var pairs = 0;
      final hashes = [
        for (var seed = 200; seed < 220; seed++)
          hashesOf(PhotoSet.scene(seed)).pHash,
      ];
      for (var i = 0; i < hashes.length; i++) {
        for (var j = i + 1; j < hashes.length; j++) {
          total += hammingDistance(hashes[i], hashes[j]);
          pairs++;
        }
      }
      expect(total / pairs, greaterThan(24));
    });
  });
}
