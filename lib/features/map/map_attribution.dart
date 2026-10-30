import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// "© OpenStreetMap contributors" in the bottom right corner of a map, as
/// the tiles' usage policy asks.
class MapAttribution extends StatelessWidget {
  /// Creates the attribution, in [fontSize] (smaller on the mini map).
  const MapAttribution({this.fontSize = 11, super.key});

  /// Size of the text.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: ColoredBox(
        color: Colors.white70,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Text(
            AppLocalizations.of(context).mapAttribution,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fontSize, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}
