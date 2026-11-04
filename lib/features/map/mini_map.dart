import 'dart:async';

import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/domain/geo.dart';
import 'package:clean_gallery/features/map/map_attribution.dart';
import 'package:clean_gallery/features/map/map_tiles.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

/// A small, still map of [point] with an accent dot, as in the viewer's info
/// panel. Tapping it opens the app's map there.
class MiniMap extends ConsumerWidget {
  /// Creates the mini map.
  const MiniMap({required this.point, super.key});

  /// Where the item was taken.
  final GeoPoint point;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final center = LatLng(point.latitude, point.longitude);
    return Semantics(
      button: true,
      label: l10n.infoMiniMap,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 140,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 14,
                  backgroundColor: colors.surfaceContainerHigh,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: openStreetMapTiles,
                    userAgentPackageName: mapUserAgentPackage,
                    tileProvider: ref.watch(mapTileProviderProvider),
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 22,
                        height: 22,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const MapAttribution(fontSize: 9),
                ],
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () =>
                        unawaited(context.push(AppRoutes.map, extra: point)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
