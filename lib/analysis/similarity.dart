import 'dart:math' as math;

import 'package:clean_gallery/analysis/bk_tree.dart';
import 'package:clean_gallery/analysis/perceptual_hash.dart';
import 'package:clean_gallery/analysis/union_find.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'similarity.freezed.dart';

/// How eager the similar photo search is, chosen in Settings.
enum SimilaritySensitivity {
  /// Only near-identical photos.
  low,

  /// The brief's defaults.
  medium,

  /// Also photos with small differences (framing, a moved subject).
  high,

  /// Thresholds set by hand in the advanced mode.
  custom,
}

/// Thresholds deciding whether two photos are similar, see
/// [findSimilarGroups].
@freezed
abstract class SimilarityThresholds with _$SimilarityThresholds {
  /// Creates thresholds.
  const factory SimilarityThresholds({
    /// Largest pHash distance for two photos of any date, when their
    /// aspect ratios match.
    required int strict,

    /// Largest pHash distance for two photos taken within [window].
    required int loose,

    /// Longest time between two photos for the [loose] rule.
    required Duration window,
  }) = _SimilarityThresholds;

  /// Thresholds of a preset; [SimilaritySensitivity.custom] has none and
  /// gives [medium].
  factory SimilarityThresholds.of(SimilaritySensitivity sensitivity) =>
      switch (sensitivity) {
        SimilaritySensitivity.low => low,
        SimilaritySensitivity.medium || SimilaritySensitivity.custom => medium,
        SimilaritySensitivity.high => high,
      };

  /// Fewer, safer matches.
  static const low = SimilarityThresholds(
    strict: 4,
    loose: 10,
    window: Duration(seconds: 5),
  );

  /// The brief's defaults.
  static const medium = SimilarityThresholds(
    strict: 6,
    loose: 12,
    window: Duration(seconds: 10),
  );

  /// More matches, more to review.
  static const high = SimilarityThresholds(
    strict: 8,
    loose: 14,
    window: Duration(seconds: 30),
  );

  /// Largest strict and loose distances offered in the advanced mode.
  static const maxDistance = 20;

  /// Longest window offered in the advanced mode.
  static const maxWindow = Duration(seconds: 60);

  /// Largest relative difference of aspect ratio for the strict rule.
  static const aspectTolerance = 0.02;
}

/// A photo with its perceptual hashes, as compared by [findSimilarGroups].
final class HashedPhoto {
  /// Creates a photo.
  const HashedPhoto({
    required this.id,
    required this.hashes,
    required this.width,
    required this.height,
    required this.takenAt,
    this.cameraModel,
    this.latitude,
    this.longitude,
  });

  /// Database id.
  final int id;

  /// Its dHash and pHash.
  final PerceptualHashes hashes;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Capture date.
  final DateTime takenAt;

  /// Camera model, when known.
  final String? cameraModel;

  /// GPS latitude, when known.
  final double? latitude;

  /// GPS longitude, when known.
  final double? longitude;

  double get _aspect => width > 0 && height > 0 ? width / height : 0;
}

/// A group of similar photos: database ids and, for each, the confidence
/// (0 to 1) of its closest match in the group.
typedef SimilarGroup = Map<int, double>;

/// Groups of similar [photos].
///
/// Two photos are similar when their pHash distance is
///
/// - at most `thresholds.strict` and their aspect ratios differ by at most
///   2 %, whatever their dates; or
/// - at most `thresholds.loose` and they were taken at most
///   `thresholds.window` apart.
///
/// Pairs listed in [ignored] (user's "Not duplicates", as `(a, b)` with
/// `a < b`) and pairs of photos of the same certain group ([certainGroup],
/// group id by photo id) are never linked. Similar pairs are joined
/// transitively (union-find).
///
/// Strict pairs are found with a [BkTree]; loose pairs by walking the
/// photos in date order, comparing each only with those of the next
/// [SimilarityThresholds.window]. Nothing is compared with everything.
List<SimilarGroup> findSimilarGroups(
  List<HashedPhoto> photos,
  SimilarityThresholds thresholds, {
  Set<(int, int)> ignored = const {},
  Map<int, int> certainGroup = const {},
}) {
  final sets = UnionFind(photos.length);
  final confidence = List<double>.filled(photos.length, 0);

  void link(int i, int j, int distance) {
    final a = photos[i];
    final b = photos[j];
    final pair = a.id < b.id ? (a.id, b.id) : (b.id, a.id);
    if (ignored.contains(pair)) return;
    final group = certainGroup[a.id];
    if (group != null && group == certainGroup[b.id]) return;
    sets.union(i, j);
    final score = pairConfidence(a, b, distance);
    confidence[i] = math.max(confidence[i], score);
    confidence[j] = math.max(confidence[j], score);
  }

  final tree = BkTree();
  for (var i = 0; i < photos.length; i++) {
    tree.add(photos[i].hashes.pHash, i);
  }
  for (var i = 0; i < photos.length; i++) {
    tree.search(photos[i].hashes.pHash, thresholds.strict, (j, distance) {
      if (j > i && _sameAspect(photos[i], photos[j])) link(i, j, distance);
    });
  }

  final byDate = List.generate(photos.length, (i) => i)
    ..sort((a, b) => photos[a].takenAt.compareTo(photos[b].takenAt));
  for (var k = 0; k < byDate.length; k++) {
    final i = byDate[k];
    final limit = photos[i].takenAt.add(thresholds.window);
    for (var m = k + 1; m < byDate.length; m++) {
      final j = byDate[m];
      if (photos[j].takenAt.isAfter(limit)) break;
      final distance = hammingDistance(
        photos[i].hashes.pHash,
        photos[j].hashes.pHash,
      );
      if (distance <= thresholds.loose) link(i, j, distance);
    }
  }

  return [
    for (final members in sets.groups())
      {for (final i in members) photos[i].id: confidence[i]},
  ];
}

/// Whether the aspect ratios of [a] and [b] differ by at most
/// [SimilarityThresholds.aspectTolerance].
bool _sameAspect(HashedPhoto a, HashedPhoto b) {
  final ratioA = a._aspect;
  final ratioB = b._aspect;
  if (ratioA == 0 || ratioB == 0) return false;
  return (ratioA / ratioB - 1).abs() <= SimilarityThresholds.aspectTolerance;
}

/// Bonus to the confidence when both photos come from the same camera.
const sameCameraBonus = 0.1;

/// Bonus to the confidence when both photos were taken within
/// [nearbyMeters] of each other.
const nearbyBonus = 0.1;

/// Distance under which two photos count as taken at the same place.
const nearbyMeters = 100.0;

/// Confidence (0 to 1) that [a] and [b], [distance] pHash bits apart, show
/// the same scene: closer pHash and dHash give more, and the same camera
/// and a nearby place add a bonus.
double pairConfidence(HashedPhoto a, HashedPhoto b, int distance) {
  final dDistance = hammingDistance(a.hashes.dHash, b.hashes.dHash);
  var score = 1 - (distance + dDistance) / 64;
  final camera = a.cameraModel;
  if (camera != null && camera.isNotEmpty && camera == b.cameraModel) {
    score += sameCameraBonus;
  }
  if (_metersApart(a, b) case final meters? when meters <= nearbyMeters) {
    score += nearbyBonus;
  }
  return score.clamp(0, 1).toDouble();
}

/// Distance between the places of [a] and [b] in meters (haversine), or
/// `null` when either has no location.
double? _metersApart(HashedPhoto a, HashedPhoto b) {
  final (lat1, lon1, lat2, lon2) = (
    a.latitude,
    a.longitude,
    b.latitude,
    b.longitude,
  );
  if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
    return null;
  }
  const earthRadius = 6371000.0;
  double radians(double degrees) => degrees * math.pi / 180;
  final dLat = radians(lat2 - lat1);
  final dLon = radians(lon2 - lon1);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(radians(lat1)) *
          math.cos(radians(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(h));
}
