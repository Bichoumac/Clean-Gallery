import 'dart:math' as math;

import 'package:clean_gallery/analysis/bk_tree.dart';
import 'package:clean_gallery/analysis/perceptual_hash.dart';
import 'package:clean_gallery/analysis/similarity.dart';
import 'package:clean_gallery/analysis/union_find.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'photo_set.dart';

void main() {
  final noon = DateTime(2026, 5, 1, 12);

  HashedPhoto photo(
    int id,
    int pHash, {
    int dHash = 0,
    int width = 4000,
    int height = 3000,
    DateTime? takenAt,
    String? camera,
    double? latitude,
    double? longitude,
  }) => HashedPhoto(
    id: id,
    hashes: (dHash: dHash, pHash: pHash),
    width: width,
    height: height,
    takenAt: takenAt ?? noon.add(Duration(days: id)),
    cameraModel: camera,
    latitude: latitude,
    longitude: longitude,
  );

  /// A hash [bits] bits away from [hash]: its bits from [from] up flipped.
  int flip(int hash, int bits, {int from = 0}) =>
      hash ^ (((1 << bits) - 1) << from);

  List<List<int>> ids(List<SimilarGroup> groups) =>
      [for (final group in groups) group.keys.toList()..sort()]
        ..sort((a, b) => a.first.compareTo(b.first));

  group('BkTree', () {
    test('finds exactly the hashes within the radius', () {
      final random = math.Random(4);
      final hashes = [
        for (var i = 0; i < 500; i++)
          random.nextInt(1 << 32) << 32 | random.nextInt(1 << 32),
      ];
      final tree = BkTree();
      for (var i = 0; i < hashes.length; i++) {
        tree.add(hashes[i], i);
      }
      for (final query in hashes.take(20)) {
        for (final radius in [0, 6, 20, 30]) {
          final found = <int>{};
          tree.search(query, radius, (index, distance) {
            expect(distance, hammingDistance(query, hashes[index]));
            found.add(index);
          });
          expect(found, {
            for (var i = 0; i < hashes.length; i++)
              if (hammingDistance(query, hashes[i]) <= radius) i,
          });
        }
      }
    });

    test('keeps every value of an identical hash', () {
      final tree = BkTree()
        ..add(42, 0)
        ..add(42, 1);
      final found = <int>[];
      tree.search(42, 0, (index, _) => found.add(index));
      expect(found, [0, 1]);
    });
  });

  group('UnionFind', () {
    test('joins transitively and lists sets of two or more', () {
      final sets = UnionFind(6)
        ..union(0, 1)
        ..union(1, 2)
        ..union(4, 5);
      expect(sets.groups(), [
        [0, 1, 2],
        [4, 5],
      ]);
      expect(sets.find(0), sets.find(2));
      expect(sets.find(3), isNot(sets.find(0)));
    });
  });

  group('findSimilarGroups', () {
    const thresholds = SimilarityThresholds.medium;
    const base = 0x01234567 << 32 | 0x89ABCDEF;

    test('strict rule: close hashes, any date, same aspect ratio', () {
      final groups = findSimilarGroups([
        photo(1, base),
        photo(2, flip(base, 6), takenAt: DateTime(2020)),
        photo(3, flip(base, 20)),
      ], thresholds);
      expect(ids(groups), [
        [1, 2],
      ]);
    });

    test('strict rule needs aspect ratios within 2 %', () {
      expect(
        findSimilarGroups([
          photo(1, base),
          photo(2, base, height: 3200),
        ], thresholds),
        isEmpty,
      );
      expect(
        findSimilarGroups([
          photo(1, base),
          photo(2, base, height: 3050),
        ], thresholds),
        hasLength(1),
      );
    });

    test('loose rule: farther hashes within the time window', () {
      final groups = findSimilarGroups([
        photo(1, base, takenAt: noon),
        photo(2, flip(base, 12), takenAt: noon.add(const Duration(seconds: 9))),
        // Same distance, but outside the window.
        photo(
          3,
          flip(base, 12, from: 40),
          takenAt: noon.add(const Duration(hours: 1)),
        ),
        // Inside the window, but too far apart.
        photo(
          4,
          flip(base, 13, from: 20),
          takenAt: noon.add(const Duration(seconds: 2)),
        ),
      ], thresholds);
      expect(ids(groups), [
        [1, 2],
      ]);
    });

    test('loose rule ignores aspect ratio', () {
      final groups = findSimilarGroups([
        photo(1, base, takenAt: noon),
        photo(
          2,
          flip(base, 3),
          width: 3000,
          takenAt: noon.add(const Duration(seconds: 1)),
        ),
      ], thresholds);
      expect(groups, hasLength(1));
    });

    test('joins chains of similar photos into one group', () {
      final groups = findSimilarGroups([
        photo(1, base),
        photo(2, flip(base, 5)),
        photo(3, flip(base, 10)),
      ], thresholds);
      expect(ids(groups), [
        [1, 2, 3],
      ]);
    });

    test('never links ignored pairs', () {
      final photos = [photo(1, base), photo(2, base), photo(3, base)];
      expect(ids(findSimilarGroups(photos, thresholds, ignored: {(1, 2)})), [
        [1, 2, 3],
      ], reason: '1 and 2 are still joined through 3');
      expect(
        findSimilarGroups(
          photos,
          thresholds,
          ignored: {(1, 2), (1, 3), (2, 3)},
        ),
        isEmpty,
      );
    });

    test('skips pairs already in one certain group', () {
      final photos = [photo(1, base), photo(2, base), photo(3, flip(base, 2))];
      expect(
        findSimilarGroups(photos, thresholds, certainGroup: {1: 7, 2: 7}),
        hasLength(1),
        reason: 'the copies are each similar to photo 3',
      );
      expect(
        findSimilarGroups(
          photos.take(2).toList(),
          thresholds,
          certainGroup: {1: 7, 2: 7},
        ),
        isEmpty,
      );
    });

    test('each sensitivity is stricter than the next', () {
      const low = SimilarityThresholds.low;
      const high = SimilarityThresholds.high;
      expect(low.strict, lessThan(thresholds.strict));
      expect(thresholds.strict, lessThan(high.strict));
      expect(low.loose, lessThan(thresholds.loose));
      expect(thresholds.loose, lessThan(high.loose));
      expect(low.window, lessThan(thresholds.window));
      expect(thresholds.window, lessThan(high.window));
      expect(SimilarityThresholds.of(SimilaritySensitivity.medium), thresholds);
    });
  });

  group('pairConfidence', () {
    test('is 1 for identical hashes, lower as they drift apart', () {
      final a = photo(1, 0);
      expect(pairConfidence(a, photo(2, 0), 0), 1);
      expect(pairConfidence(a, photo(2, flip(0, 8)), 8), closeTo(0.875, 1e-9));
    });

    test('gains from the same camera and a nearby place', () {
      final a = photo(
        1,
        0,
        camera: 'SM-A546B',
        latitude: 48.8584,
        longitude: 2.2945,
      );
      final near = photo(
        2,
        flip(0, 16),
        camera: 'SM-A546B',
        latitude: 48.8588,
        longitude: 2.2945,
      );
      final far = photo(
        3,
        flip(0, 16),
        camera: 'Pixel 8',
        latitude: 45.76,
        longitude: 4.83,
      );
      expect(pairConfidence(a, near, 16), closeTo(0.95, 1e-9));
      expect(pairConfidence(a, far, 16), closeTo(0.75, 1e-9));
    });
  });

  group('test photo set', () {
    HashedPhoto shot(int id, img.Image image, DateTime takenAt) => HashedPhoto(
      id: id,
      hashes: perceptualHashes(PhotoSet.thumbnail(image)),
      width: image.width,
      height: image.height,
      takenAt: takenAt,
    );

    test('groups copies and quick shots, not different photos', () {
      final beach = PhotoSet.scene(1);
      final city = PhotoSet.scene(2);
      final groups = findSimilarGroups([
        shot(1, beach, noon),
        // Received through a messaging app days later.
        shot(
          2,
          PhotoSet.recompressed(PhotoSet.resized(beach, 0.5), quality: 50),
          noon.add(const Duration(days: 3)),
        ),
        // A second shot, the subject moved a little.
        shot(
          3,
          PhotoSet.scene(1, shift: 15),
          noon.add(const Duration(seconds: 4)),
        ),
        // Same place much later, the subject moved a lot.
        shot(
          4,
          PhotoSet.scene(1, shift: 60),
          noon.add(const Duration(minutes: 5)),
        ),
        shot(5, city, noon.add(const Duration(seconds: 2))),
        shot(6, PhotoSet.scene(3), noon.add(const Duration(seconds: 6))),
      ], SimilarityThresholds.medium);
      expect(ids(groups), [
        [1, 2, 3],
      ]);
    });
  });
}
