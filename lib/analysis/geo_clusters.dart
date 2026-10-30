import 'dart:math' as math;

import 'package:clean_gallery/domain/geo.dart';

/// Side of a map tile in pixels, as in the Web Mercator tiles of the map.
const mapTileSize = 256.0;

/// Items of the map near each other at one zoom level, shown as one marker.
final class GeoCluster {
  /// Creates a cluster.
  const GeoCluster({
    required this.area,
    required this.center,
    required this.cover,
    required this.count,
  });

  /// Grid cell the items are in: listing the items of this area gives
  /// exactly the items of the cluster.
  final GeoArea area;

  /// Mean position of the items, where the marker stands.
  final GeoPoint center;

  /// Item shown on the marker: the newest.
  final LocatedItem cover;

  /// Number of items.
  final int count;
}

/// Groups [items] into clusters for a map at [zoom], by cells of about
/// [cellPixels] screen pixels of the Web Mercator projection.
///
/// A grid rather than distances between items: every item is visited once,
/// so tens of thousands of photos cluster in a few milliseconds, and each
/// cluster is a rectangle the item list can be filtered by. [items] are
/// newest first; each cluster's cover is its first item.
List<GeoCluster> clusterItems(
  List<LocatedItem> items, {
  required int zoom,
  double cellPixels = 80,
}) {
  final cells = (mapTileSize * math.pow(2, zoom) / cellPixels).ceil();
  final byCell = <int, _Cell>{};
  for (final item in items) {
    final (x, y) = _project(item.position);
    final cx = (x * cells).floor().clamp(0, cells - 1);
    final cy = (y * cells).floor().clamp(0, cells - 1);
    (byCell[cy * cells + cx] ??= _Cell(cx, cy, item)).add(item.position);
  }
  return [
    for (final cell in byCell.values)
      GeoCluster(
        area: _area(cell.x, cell.y, cells),
        center: (
          latitude: cell.latitudes / cell.count,
          longitude: cell.longitudes / cell.count,
        ),
        cover: cell.cover,
        count: cell.count,
      ),
  ];
}

/// Web Mercator position of [point], from 0 to 1 in both directions, the
/// origin at the north-west corner.
(double, double) _project(GeoPoint point) {
  final latitude = point.latitude.clamp(-85.05112878, 85.05112878);
  final sin = math.sin(latitude * math.pi / 180);
  final y = 0.5 - math.log((1 + sin) / (1 - sin)) / (4 * math.pi);
  return ((point.longitude + 180) / 360, y);
}

/// Latitude at [y] of the Web Mercator projection, from 0 (north) to 1.
double _latitudeAt(double y) =>
    math.atan(_sinh(math.pi * (1 - 2 * y))) * 180 / math.pi;

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;

/// Area of the cell at [x], [y] of a grid of [cells] × [cells]. The cells
/// at the edges stretch to the poles and the antimeridian, so every item
/// is in one.
GeoArea _area(int x, int y, int cells) => GeoArea(
  south: y == cells - 1 ? -90 : _latitudeAt((y + 1) / cells),
  north: y == 0 ? 90.0001 : _latitudeAt(y / cells),
  west: x == 0 ? -180 : x / cells * 360 - 180,
  east: x == cells - 1 ? 180.0001 : (x + 1) / cells * 360 - 180,
);

class _Cell {
  _Cell(this.x, this.y, this.cover);

  final int x;
  final int y;
  final LocatedItem cover;
  int count = 0;
  double latitudes = 0;
  double longitudes = 0;

  void add(GeoPoint position) {
    count++;
    latitudes += position.latitude;
    longitudes += position.longitude;
  }
}
