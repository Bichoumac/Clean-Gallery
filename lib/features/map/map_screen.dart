import 'dart:async';

import 'package:clean_gallery/analysis/geo_clusters.dart';
import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/location_scan.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/geo.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/features/map/map_attribution.dart';
import 'package:clean_gallery/features/map/map_tiles.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'map_screen.g.dart';

/// Size of a cluster marker, in logical pixels.
const _markerSize = 60.0;

/// Whether the app may read where photos were taken.
@riverpod
Future<bool> locationAccess(Ref ref) =>
    ref.watch(permissionServiceProvider).hasLocationAccess();

/// The photos and videos of the library on an OpenStreetMap map, grouped
/// into clusters that show their newest item and their count. Tapping a
/// cluster opens the grid of its items; a single item opens the viewer.
///
/// Opens on [center] when given (from the info panel), on [area] when
/// given, otherwise fitted to every located item.
///
/// With [pickArea] (search), a button pops the area shown as a `GeoArea`,
/// and a cluster zooms in instead of opening.
class MapScreen extends ConsumerWidget {
  /// Creates the map.
  const MapScreen({this.center, this.area, this.pickArea = false, super.key});

  /// Where to open the map, zoomed in.
  final GeoPoint? center;

  /// Area to open the map on, e.g. the one a search is limited to.
  final GeoArea? area;

  /// Whether the map is open to pick an area.
  final bool pickArea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final allowed = ref.watch(locationAccessProvider).value;
    final located = ref.watch(locatedMediaProvider).value;

    return Scaffold(
      body: Stack(
        children: [
          if (located == null)
            const Center(child: CircularProgressIndicator())
          else
            _ClusterMap(
              items: located,
              center: center,
              area: area,
              pickArea: pickArea && allowed != false,
            ),
          _TopBar(title: pickArea ? l10n.mapPickTitle : l10n.mapTitle),
          if (allowed == false)
            _Notice(
              icon: Icons.location_off_outlined,
              title: l10n.mapLocationTitle,
              body: l10n.mapLocationBody,
              action: FilledButton(
                onPressed: () async {
                  final granted = await ref
                      .read(permissionServiceProvider)
                      .requestLocationAccess();
                  ref.invalidate(locationAccessProvider);
                  if (granted) {
                    unawaited(ref.read(locationScanProvider.notifier).run());
                  }
                },
                child: Text(l10n.mapLocationButton),
              ),
            )
          else if (!pickArea && located != null && located.isEmpty)
            _Notice(
              icon: Icons.map_outlined,
              title: l10n.mapEmptyTitle,
              body: l10n.mapEmptyBody,
            ),
        ],
      ),
    );
  }
}

/// The map itself, with one marker per cluster at the current zoom level.
class _ClusterMap extends ConsumerStatefulWidget {
  const _ClusterMap({
    required this.items,
    required this.center,
    required this.area,
    required this.pickArea,
  });

  final List<LocatedItem> items;
  final GeoPoint? center;
  final GeoArea? area;

  /// Whether to show the button that pops the area shown.
  final bool pickArea;

  @override
  ConsumerState<_ClusterMap> createState() => _ClusterMapState();
}

class _ClusterMapState extends ConsumerState<_ClusterMap> {
  final _controller = MapController();

  /// Read in [initState]: `ref` cannot be used in [dispose].
  late final DuplicateScan _scan;

  /// Zoom level the clusters are made for: the camera's, rounded.
  late int _zoom;

  /// Clusters by zoom level, for [_clustersOf].
  final _clusters = <int, List<GeoCluster>>{};

  @override
  void initState() {
    super.initState();
    _zoom = widget.center == null ? 2 : 15;
    // The analysis would compete with the markers for MediaStore's thumbnail
    // rendering, as in the viewer.
    _scan = ref.read(duplicateScanProvider.notifier)..pause();
  }

  @override
  void dispose() {
    _scan.resume();
    _controller.dispose();
    super.dispose();
  }

  void _onZoom(double zoom) {
    final level = zoom.round().clamp(0, mapMaxZoom.toInt());
    if (level != _zoom) setState(() => _zoom = level);
  }

  @override
  void didUpdateWidget(_ClusterMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) _clusters.clear();
  }

  List<GeoCluster> _clustersOf(int zoom) =>
      _clusters[zoom] ??= clusterItems(widget.items, zoom: zoom);

  CameraFit? get _initialFit {
    if (widget.area case final area?) {
      return CameraFit.bounds(bounds: _bounds(area));
    }
    if (widget.center != null || widget.items.isEmpty) return null;
    final points = [for (final i in widget.items) _latLng(i.position)];
    final bounds = LatLngBounds.fromPoints(points);
    // One place: a fitted camera would zoom in to the street.
    if (bounds.north == bounds.south && bounds.east == bounds.west) {
      return CameraFit.coordinates(coordinates: points, maxZoom: 14);
    }
    return CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.fromLTRB(48, 120, 48, 64),
      maxZoom: 14,
    );
  }

  /// The area shown, as a search criterion. A view across the antimeridian
  /// takes every longitude.
  GeoArea get _shownArea {
    final b = _controller.camera.visibleBounds;
    final across = b.west > b.east;
    return GeoArea(
      south: b.south,
      west: across ? -180 : b.west,
      north: b.north,
      east: across ? 180 : b.east,
    );
  }

  /// Zooms onto [cluster] (picking an area).
  void _zoomOn(GeoCluster cluster) => _controller.fitCamera(
    CameraFit.bounds(
      bounds: _bounds(cluster.area),
      padding: const EdgeInsets.all(48),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final center = widget.center;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: center == null ? const LatLng(30, 10) : _latLng(center),
        initialZoom: _zoom.toDouble(),
        initialCameraFit: _initialFit,
        minZoom: 2,
        maxZoom: mapMaxZoom,
        backgroundColor: colors.surfaceContainerHigh,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        // The fitted camera's zoom is known once the map is laid out.
        onMapReady: () => _onZoom(_controller.camera.zoom),
        onPositionChanged: (camera, _) => _onZoom(camera.zoom),
      ),
      children: [
        TileLayer(
          urlTemplate: openStreetMapTiles,
          userAgentPackageName: mapUserAgentPackage,
          maxNativeZoom: mapMaxZoom.toInt(),
          tileProvider: ref.watch(mapTileProviderProvider),
          tileBuilder: dark ? darkModeTileBuilder : null,
        ),
        MarkerLayer(
          markers: [
            for (final cluster in _clustersOf(_zoom))
              Marker(
                key: ValueKey('$_zoom-${cluster.cover.item.id}'),
                point: _latLng(cluster.center),
                width: _markerSize,
                height: _markerSize,
                child: _ClusterMarker(
                  cluster: cluster,
                  onTap: widget.pickArea ? () => _zoomOn(cluster) : null,
                ),
              ),
          ],
        ),
        const MapAttribution(),
        if (widget.pickArea)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                // Above the attribution.
                padding: const EdgeInsets.only(bottom: 40),
                child: FilledButton.icon(
                  onPressed: () => context.pop(_shownArea),
                  icon: const Icon(Icons.search_rounded),
                  label: Text(l10n.mapPickButton),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

LatLng _latLng(GeoPoint point) => LatLng(point.latitude, point.longitude);

LatLngBounds _bounds(GeoArea area) =>
    LatLngBounds(LatLng(area.south, area.west), LatLng(area.north, area.east));

/// A cluster on the map: its newest item in a rounded square, and the
/// number of items when there are several.
class _ClusterMarker extends ConsumerWidget {
  const _ClusterMarker({required this.cluster, this.onTap});

  final GeoCluster cluster;

  /// Replaces opening the cluster, e.g. zooming in while picking an area.
  final VoidCallback? onTap;

  void _open(BuildContext context) {
    final selection = MediaSelection(area: cluster.area);
    if (cluster.count == 1) {
      unawaited(
        context.push(
          AppRoutes.viewer,
          extra: ViewerArgs(selection: selection, initialIndex: 0),
        ),
      );
    } else {
      unawaited(context.push(AppRoutes.mapArea, extra: cluster.area));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      // Its own node: TalkBack reads each cluster as a button.
      container: true,
      button: true,
      label: l10n.mapClusterLabel(cluster.count),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap ?? () => _open(context),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: _MarkerCover(item: cluster.cover.item),
                ),
              ),
            ),
            if (cluster.count > 1)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 26),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    _compactCount(cluster.count),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The photo of a marker, grey until it is there.
///
/// A thumbnail can fail while MediaStore is busy, and nothing asks for it
/// again while the marker stays on screen: it is asked for again a few times,
/// then an icon says it could not be read.
class _MarkerCover extends ConsumerStatefulWidget {
  const _MarkerCover({required this.item});

  final MediaItem item;

  @override
  ConsumerState<_MarkerCover> createState() => _MarkerCoverState();
}

class _MarkerCoverState extends ConsumerState<_MarkerCover> {
  static const _retries = 3;

  int _attempt = 0;
  Timer? _retry;

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  void _scheduleRetry(ImageProvider image) {
    if (_retry != null || _attempt >= _retries) return;
    _retry = Timer(Duration(seconds: _attempt + 1), () {
      unawaited(image.evict());
      if (mounted) {
        setState(() {
          _retry = null;
          _attempt++;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final image = ref
        .watch(mediaSourceProvider)
        .thumbnail(widget.item, size: 192);
    return ColoredBox(
      color: colors.surfaceContainerHigh,
      child: Image(
        // A new state: an image that failed is not loaded again otherwise.
        key: ValueKey(_attempt),
        image: image,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          _scheduleRetry(image);
          return _attempt < _retries
              ? const SizedBox.shrink()
              : Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colors.onSurfaceVariant,
                  ),
                );
        },
      ),
    );
  }
}

/// [count] in at most four characters: 999, 1.2k, 12k.
String _compactCount(int count) => switch (count) {
  < 1000 => '$count',
  < 10000 => '${(count / 1000).toStringAsFixed(1)}k',
  _ => '${count ~/ 1000}k',
};

/// Back button and title over the map.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
              ),
              child: const BackButton(),
            ),
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card at the bottom of the map: why nothing shows, and what to do.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(title, style: theme.textTheme.titleMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 16),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
