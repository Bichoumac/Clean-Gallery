import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/geo.dart';
import 'package:clean_gallery/features/library/media_timeline_view.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The photos and videos of one cluster of the map, as a timeline.
class MapAreaScreen extends StatelessWidget {
  /// Creates the page of the items taken in [area].
  const MapAreaScreen({required this.area, super.key});

  /// Cell of the map's grid the cluster covers.
  final GeoArea area;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: MediaTimelineView(
        selection: MediaSelection(area: area),
        title: l10n.mapAreaTitle,
        emptyTitle: l10n.mapAreaTitle,
        showBackButton: true,
        slideshowTitle: l10n.mapAreaTitle,
      ),
    );
  }
}
