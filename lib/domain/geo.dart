import 'package:clean_gallery/domain/media_item.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'geo.freezed.dart';

/// A position on Earth, in degrees.
typedef GeoPoint = ({double latitude, double longitude});

/// A rectangle of latitudes and longitudes: from [south] (included) to
/// [north] (excluded), and from [west] (included) to [east] (excluded).
///
/// The area of a cluster on the map, used to list the items in it.
@freezed
abstract class GeoArea with _$GeoArea {
  /// Creates an area.
  const factory GeoArea({
    required double south,
    required double west,
    required double north,
    required double east,
  }) = _GeoArea;

  const GeoArea._();

  /// Whether [point] is inside the area.
  bool contains(GeoPoint point) =>
      point.latitude >= south &&
      point.latitude < north &&
      point.longitude >= west &&
      point.longitude < east;
}

/// An item with the location read from its file, as shown on the map.
final class LocatedItem {
  /// Creates a located item.
  const LocatedItem({required this.item, required this.position});

  /// The photo or video.
  final MediaItem item;

  /// Where it was taken.
  final GeoPoint position;
}
