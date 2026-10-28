import 'package:flutter_map/flutter_map.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'map_tiles.g.dart';

/// OpenStreetMap's standard tiles. Their usage policy asks for a real user
/// agent ([mapUserAgentPackage]) and a visible attribution.
const openStreetMapTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Application id sent in the tiles' user agent, as OpenStreetMap asks.
const mapUserAgentPackage = 'com.bichoumac.clean_gallery';

/// Highest zoom of OpenStreetMap's standard tiles.
const mapMaxZoom = 19.0;

/// Where map tiles come from: OpenStreetMap over the network, with
/// flutter_map's built-in disk cache. Only tile coordinates are requested;
/// no photo or location of the library is ever sent. Tests replace it with
/// blank tiles.
@Riverpod(keepAlive: true)
TileProvider mapTileProvider(Ref ref) {
  final provider = NetworkTileProvider();
  ref.onDispose(provider.dispose);
  return provider;
}
