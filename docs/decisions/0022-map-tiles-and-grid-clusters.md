# ADR 0022 — Map: OpenStreetMap tiles with flutter_map, clusters on a grid

How the map shows the library's photos by place, and what it costs in privacy and dependencies.

Last updated: 2026-10-28 — Milestone M6

- **Status**: Accepted
- **Date**: 2026-10-28

## Context

The brief asks for an OpenStreetMap map with clusters of geotagged photos, each with a thumbnail, and the grid of a cluster's photos on tap, respecting OpenStreetMap's tile usage policy; it recommends `flutter_map`, OpenStreetMap tiles and marker clustering. The product owner asked on 2026-10-28 to build it before the editor. Locations were not stored yet: `assets.latitude` and `longitude` existed but were never filled.

## Decision

- **flutter_map 8 and latlong2** for the map, with OpenStreetMap's standard tiles, the app id in the user agent and the attribution always visible. flutter_map's built-in disk cache keeps tiles already seen.
- **Clusters computed by the app** (`clusterItems`, pure Dart in `lib/analysis/`): each item goes in a cell of a grid of about 80 screen pixels at the current zoom level (Web Mercator), the marker at the mean position of its items, the newest item as its thumbnail. One pass over the items per zoom level; flutter_map's `MarkerLayer` only builds the markers on screen.
- **A cluster is a rectangle** (`GeoArea`): its grid is the timeline of `MediaSelection(area: …)`, a plain query on latitude and longitude, so it has every feature of a timeline (viewer, selection, sort) and lists exactly the cluster's items.
- **Locations read by a scan of their own** (`LocationScan`, native method `locations`), file headers only, once per file (`assets.location_read`, schema version 5), and only with `ACCESS_MEDIA_LOCATION`, since without it Android hides every location.
- **`INTERNET` in the release manifest**, for the tiles.

## Alternatives considered

- **flutter_map_marker_cluster**: clusters by distance with animations, but builds a marker widget per item up front and offers no area to list a cluster by; its thumbnails and counts would still have been our own widgets. Another dependency for less control.
- **Distance-based clustering in Dart** (merging items closer than N pixels): no gap on cell edges, but quadratic or needing a spatial index, and a cluster would not be a rectangle the item list can be filtered by.
- **Locations read during the index sync** (`mediaDetails`): would slow the sync, which must stay fast at launch, and redo the work at every change of a row.
- **Offline maps** (bundled vector tiles): no network at all, but tens of megabytes and another rendering library. Kept in mind if network access becomes a concern.

## Consequences

- The app asks for network access in release builds. Only tile coordinates are requested; OpenStreetMap can tell which area the map shows, never which photos are there.
- Two new dependencies (`flutter_map`, `latlong2`) and their own (`http`, `proj4dart`…).
- Items on either side of a cell edge are two clusters until zoomed out.
- The info panel's mini map, planned for M7 with the map ([viewer.md](../features/viewer.md#info-panel)), comes with it.
