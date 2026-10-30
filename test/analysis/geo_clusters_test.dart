import 'package:clean_gallery/analysis/geo_clusters.dart';
import 'package:clean_gallery/domain/geo.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  LocatedItem at(int id, double latitude, double longitude) => LocatedItem(
    item: testItem(id),
    position: (latitude: latitude, longitude: longitude),
  );

  // Newest first: two in Paris 300 m apart, one in Lyon, one in Tokyo.
  final items = [
    at(1, 48.8584, 2.2945),
    at(2, 48.8606, 2.2976),
    at(3, 45.7640, 4.8357),
    at(4, 35.6762, 139.6503),
  ];

  int countIn(GeoArea area) =>
      items.where((i) => area.contains(i.position)).length;

  test('at world zoom, France is one cluster and Tokyo another', () {
    final clusters = clusterItems(items, zoom: 1);
    expect(clusters.map((c) => c.count).toList()..sort(), [1, 3]);
  });

  test('zoomed in, nearby photos stay together, other cities split', () {
    final clusters = clusterItems(items, zoom: 12);
    expect(clusters.map((c) => c.count).toList()..sort(), [1, 1, 2]);
  });

  test('at street level, photos 300 m apart split', () {
    expect(clusterItems(items, zoom: 18), hasLength(4));
  });

  test('the cover is the newest item, the center the mean position', () {
    final paris = clusterItems(items, zoom: 12).firstWhere((c) => c.count == 2);
    expect(paris.cover.item.id, '1');
    expect(paris.center.latitude, closeTo(48.8595, 1e-9));
    expect(paris.center.longitude, closeTo(2.29605, 1e-9));
  });

  test('each area holds exactly its cluster items, at every zoom', () {
    for (var zoom = 0; zoom <= 19; zoom++) {
      final clusters = clusterItems(items, zoom: zoom);
      expect(clusters.fold(0, (sum, c) => sum + c.count), items.length);
      for (final cluster in clusters) {
        expect(countIn(cluster.area), cluster.count, reason: 'zoom $zoom');
      }
    }
  });

  test('items near the poles and the antimeridian are in an area', () {
    final edges = [at(1, 89.9, 179.99), at(2, -89.9, -180)];
    for (final cluster in clusterItems(edges, zoom: 5)) {
      expect(cluster.area.contains(cluster.cover.position), isTrue);
    }
  });
}
