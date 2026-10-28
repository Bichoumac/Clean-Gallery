# Map

The photos and videos of the library on a map, grouped by place, and the mini map of the viewer's info panel.

Last updated: 2026-10-28 — Milestone M6 (map brought forward from M7)

## Purpose

The brief: "OpenStreetMap map with geotagged photos, markers grouped into clusters with a thumbnail. Tapping a cluster → grid of photos in that area. Respect the OpenStreetMap tile usage policy (proper user agent, attribution displayed)." Built before the editor, at the product owner's request on 2026-10-28.

## User flows

1. **Albums → Map**: a tile next to *All media*, *Favorites* and *Trash*, with the number of located items and the newest one as cover. The map opens fitted to every located item (at most zoom 14, so a single place does not open at street level).
2. **Clusters**: nearby items show as one marker, a rounded thumbnail of the newest item with its count in a lime badge (999, then 1.2k, 12k). Zooming in splits them; at street level each place has its own marker.
3. **Tap a cluster**: the grid of its items, titled *In this area*, a timeline like an album (sort, date filter, selection, stacks). A marker of a single item opens the viewer directly.
4. **Info panel**: below the coordinates, a still mini map with a lime dot; tapping it opens the map there, at zoom 15 ([viewer.md](viewer.md#info-panel)).
5. **Without the location permission**: a card at the bottom of the map says that Android hides where photos were taken and offers *Allow*; once granted, locations are read at once.
6. **No located item** (location off when shooting, or still being read): a card says so.

## Reading locations

`assets.latitude` and `longitude` existed from M0 but were never filled. `LocationScan` ([location_scan.dart](../../lib/core/media/location_scan.dart)) reads them after each index sync, next to the duplicate scan:

- 20 items per native call (`locations`, on the worker thread), newest first so recent places show first; only file headers are read (EXIF, or the video's location).
- Each item is read once (`assets.location_read`, schema version 5) and again only when its file changes; *Analyze the library again* reads them all again.
- Only with `ACCESS_MEDIA_LOCATION`: without it Android hides every GPS tag, so the scan does not run rather than recording "no location" everywhere. Granting it later reads every item.
- `0, 0` is taken as "no location" (some apps write it without a fix).

## Clusters

`clusterItems` ([geo_clusters.dart](../../lib/analysis/geo_clusters.dart), pure Dart) puts each item in a cell of a grid of about 80 screen pixels at the map's zoom level (Web Mercator, as the tiles), in one pass: 20,000 items cluster in a few milliseconds, recomputed only when the zoom level changes. The marker stands at the mean position of its items. Each cluster's cell is a latitude and longitude rectangle (`GeoArea`); the grid of a cluster is the timeline of `MediaSelection(area: …)`, so it lists exactly the cluster's items. See [ADR 0022](../decisions/0022-map-tiles-and-grid-clusters.md).

## Tiles and privacy

- Tiles come from `tile.openstreetmap.org`, with the user agent `flutter_map (com.bichoumac.clean_gallery)` and the attribution *© OpenStreetMap contributors* always shown, as its [tile usage policy](https://operations.osmfoundation.org/policies/tiles/) asks. flutter_map keeps fetched tiles in its disk cache.
- Only tile coordinates are requested: OpenStreetMap can tell which area of the world the map shows, never which photos are there. No photo, location or metadata of the library leaves the phone.
- The release app now declares `INTERNET` (until then only debug builds had it); ads will need it too in M8.
- In dark mode the tiles are shown inverted (flutter_map's `darkModeTileBuilder`).

## Screens and widgets

| Widget | File | Role |
| --- | --- | --- |
| `MapScreen` | [map_screen.dart](../../lib/features/map/map_screen.dart) | Route `/map` (optional `GeoPoint` to open on): map, clusters, back button and title, permission and empty cards |
| `MapAreaScreen` | [map_area_screen.dart](../../lib/features/map/map_area_screen.dart) | Route `/map/area` (`GeoArea`): timeline of a cluster, without the Duplicates tile |
| `MiniMap` | [mini_map.dart](../../lib/features/map/mini_map.dart) | Still map of one point in the info panel |
| `MapAttribution` | [map_attribution.dart](../../lib/features/map/map_attribution.dart) | Attribution in the corner of both maps |
| `mapTileProvider` | [map_tiles.dart](../../lib/features/map/map_tiles.dart) | Where tiles come from; tests use blank tiles |

## Edge cases and error handling

- **No network**: the markers show over an empty grey background; tiles load when the network is back.
- **Items at the poles or on the antimeridian**: the edge cells stretch to ±90° and ±180°, so every item is in one.
- **An item trashed**: it leaves the map and the area grid at once.
- **A cell edge**: two nearby items on either side of a cell edge are two clusters; they merge one or two zoom levels out.

## Tests

- [geo_clusters_test.dart](../../test/analysis/geo_clusters_test.dart): clusters by zoom level, cover and center, areas holding exactly their items at every zoom, poles and antimeridian.
- [location_scan_test.dart](../../test/core/media/location_scan_test.dart): each location read once, nothing without the permission then everything once granted, a changed file read again, selection by area.
- [map_test.dart](../../test/features/map/map_test.dart): Albums tile, clusters and their grid, single item to the viewer, permission card, empty map, mini map opening the map.
- [app_database_test.dart](../../test/core/database/app_database_test.dart): migration 4 → 5.

## Known limitations / future work

- Not seen on the device yet.
- The first reading of 20,000 locations has not been timed on the phone (file headers only, expected to be a few minutes).
- No search by area yet (the brief's search, M7, will pick an area on this map).
- Clusters follow a fixed grid, not the items' own layout: a group of photos on a cell edge splits until zoomed out.
