import 'dart:math' as math;

import 'package:clean_gallery/analysis/hash_index.dart';
import 'package:clean_gallery/analysis/perceptual_hash.dart';
import 'package:clean_gallery/analysis/union_find.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'similarity.freezed.dart';

/// Tolerance of the similar photo search, chosen in Settings: how much two
/// photos may differ and still be grouped.
enum SimilaritySensitivity {
  /// Low tolerance: only near-identical photos.
  low,

  /// Medium tolerance, the default.
  medium,

  /// High tolerance: also photos with notable differences (framing, a
  /// moved subject).
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

  // Measured on public test photos (ADR 0034): the same scene panned by
  // 4 % or zoomed by 10 % is about 16 bits apart (up to 22-28); unrelated
  // photos are 32 apart (never under 22). The time window does most of the
  // work: shots of one scene are taken minutes apart, not seconds.

  /// Low tolerance: near-identical photos only.
  static const low = SimilarityThresholds(
    strict: 4,
    loose: 10,
    window: Duration(seconds: 10),
  );

  /// Medium tolerance: close photos with a few differences.
  static const medium = SimilarityThresholds(
    strict: 6,
    loose: 14,
    window: Duration(minutes: 1),
  );

  /// High tolerance: the same scene, even reframed or with a moved
  /// subject. More to review.
  static const high = SimilarityThresholds(
    strict: 10,
    loose: 18,
    window: Duration(minutes: 10),
  );

  /// Largest strict distance offered in the advanced mode. Beyond it,
  /// unrelated photos start to match, and the search slows down sharply
  /// (see ADR 0019).
  static const maxStrict = 10;

  /// Largest loose distance offered in the advanced mode. Cheap: only
  /// photos taken within the window are compared.
  static const maxLoose = 24;

  /// Longest window offered in the advanced mode.
  static const maxWindow = Duration(minutes: 30);

  /// Windows offered by the advanced mode's slider, shortest first.
  static const windowStops = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

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
/// Strict pairs are found with a [HashIndex]; loose pairs by walking the
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

  HashIndex([for (final photo in photos) photo.hashes.pHash])
      .pairsWithin(thresholds.strict, (i, j, distance) {
        if (_sameAspect(photos[i], photos[j])) link(i, j, distance);
      });

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
