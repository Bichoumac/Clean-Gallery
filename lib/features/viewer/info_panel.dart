import 'dart:ui';

import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/features/viewer/media_info.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Opens the info panel of [item] over the viewer.
///
/// See `docs/features/viewer.md#info-panel`.
Future<void> showInfoPanel(BuildContext context, MediaItem item) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      elevation: 0,
      builder: (context) => InfoPanel(item: item),
    );

/// Bottom sheet with everything known about [item], over a blurred,
/// translucent background so the photo stays visible behind it: date and
/// its source, file, size and resolution, camera settings and location.
///
/// What the index knows shows at once; the camera metadata follows when the
/// file's header has been read.
class InfoPanel extends ConsumerWidget {
  /// Creates the panel.
  const InfoPanel({required this.item, super.key});

  /// The item described.
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final info = ref.watch(mediaInfoProvider(item)).value;
    final metadata = info?.metadata;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final decimal = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    );

    final settings = [
      if (metadata?.iso case final iso?) ('ISO', '$iso'),
      if (metadata?.aperture case final aperture?)
        (l10n.infoAperture, formatAperture(aperture, locale)),
      if (metadata?.exposure case final exposure?)
        (l10n.infoShutter, formatShutter(exposure, locale)),
      if (metadata?.focalLength case final focal?)
        (
          l10n.infoFocal,
          switch (metadata?.focalLength35) {
            final equivalent? when (equivalent - focal).abs() >= 1 =>
              l10n.infoFocalEquivalent(
                _trimmed(focal, locale),
                _trimmed(equivalent, locale),
              ),
            _ => '${_trimmed(focal, locale)} mm',
          },
        ),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.55),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  _InfoRow(
                    icon: Icons.event_outlined,
                    value: formatMediaDate(context, item.takenAt),
                    label: switch (info?.dateSource) {
                      DateSource.exif => l10n.infoDateExif,
                      DateSource.filename => l10n.infoDateFilename,
                      DateSource.file => l10n.infoDateFile,
                      null => null,
                    },
                  ),
                  if (item.fileName case final name?)
                    _InfoRow(
                      icon: item.isVideo
                          ? Icons.videocam_outlined
                          : Icons.image_outlined,
                      value: name,
                      label: l10n.infoName,
                    ),
                  if (item.relativePath case final path? when path.isNotEmpty)
                    _InfoRow(
                      icon: Icons.folder_outlined,
                      value: path,
                      label: l10n.infoPath,
                    ),
                  _InfoRow(
                    icon: Icons.aspect_ratio_rounded,
                    value: l10n.infoResolutionValue(
                      item.width,
                      item.height,
                      decimal.format(item.width * item.height / 1e6),
                    ),
                    label: l10n.infoResolution,
                  ),
                  _InfoRow(
                    icon: Icons.sd_storage_outlined,
                    value: formatBytes(context, item.sizeBytes),
                    label: l10n.infoSize,
                  ),
                  if (item.isVideo)
                    _InfoRow(
                      icon: Icons.timer_outlined,
                      value: formatDuration(item.duration),
                      label: l10n.infoDuration,
                    ),
                  if (metadata?.camera case final camera?)
                    _InfoRow(
                      icon: Icons.photo_camera_outlined,
                      value: camera,
                      label: l10n.infoCamera,
                    ),
                  if (metadata?.lens case final lens?)
                    _InfoRow(
                      icon: Icons.camera_outlined,
                      value: lens,
                      label: l10n.infoLens,
                    ),
                  if (settings.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, bottom: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (label, value) in settings)
                            _Setting(label: label, value: value),
                        ],
                      ),
                    ),
                  if (metadata != null &&
                      !item.isVideo &&
                      metadata.camera == null &&
                      settings.isEmpty)
                    _InfoRow(
                      icon: Icons.photo_camera_outlined,
                      value: l10n.infoNoCameraData,
                      muted: true,
                    ),
                  if (metadata case final metadata? when metadata.hasLocation)
                    _InfoRow(
                      icon: Icons.place_outlined,
                      value: formatCoordinates(
                        metadata.latitude!,
                        metadata.longitude!,
                      ),
                      label: l10n.infoLocation,
                      selectable: true,
                    )
                  else if (info != null && !info.locationAllowed)
                    _InfoRow(
                      icon: Icons.location_off_outlined,
                      value: l10n.infoLocationNotAllowed,
                      muted: true,
                    ),
                  if (info == null)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, top: 4),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aperture as `f/1.8`.
String formatAperture(double aperture, String locale) =>
    'f/${_trimmed(aperture, locale)}';

/// Shutter speed as `1/125 s` below one second, `2 s` or `1.5 s` above.
String formatShutter(double seconds, String locale) {
  if (seconds >= 1 || seconds <= 0) return '${_trimmed(seconds, locale)} s';
  return '1/${(1 / seconds).round()} s';
}

/// Latitude and longitude in degrees with five decimals (about one metre),
/// e.g. `48.85661, 2.35222`: the form map apps accept when pasted.
String formatCoordinates(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

/// [value] with at most one decimal, none when it is whole: `1.8`, `24`.
String _trimmed(double value, String locale) {
  final format = NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: (value - value.round()).abs() < 0.05 ? 0 : 1,
  );
  return format.format(value);
}

/// One line of the panel: an icon, the value, and what it is underneath.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.value,
    this.label,
    this.muted = false,
    this.selectable = false,
  });

  final IconData icon;
  final String value;
  final String? label;

  /// Grey text: a note rather than a value.
  final bool muted;

  /// Whether the value can be selected and copied.
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = muted
        ? textTheme.bodyMedium?.copyWith(color: Colors.white70)
        : textTheme.bodyLarge?.copyWith(color: Colors.white);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 16),
            child: Icon(icon, size: 24, color: Colors.white70),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectable)
                  SelectableText(value, style: style)
                else
                  Text(value, style: style),
                if (label case final label?)
                  Text(
                    label,
                    style: textTheme.bodySmall?.copyWith(color: Colors.white60),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A camera setting (ISO, aperture…) as a small tile: value over label.
class _Setting extends StatelessWidget {
  const _Setting({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(color: Colors.white),
          ),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}
