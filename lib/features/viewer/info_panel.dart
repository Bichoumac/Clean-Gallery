import 'dart:ui';

import 'package:clean_gallery/analysis/image_quality.dart';
import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/media_metadata.dart';
import 'package:clean_gallery/features/map/mini_map.dart';
import 'package:clean_gallery/features/viewer/media_info.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return _PullToDismiss(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.4),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.9,
              ),
              child: SingleChildScrollView(
                // Always scrollable, so pulling down at the top overscrolls
                // even when everything fits: [_PullToDismiss] closes the panel.
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                // Below the content, room for the system navigation bar: the
                // sheet is drawn under it, edge to edge.
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  24 + MediaQuery.viewPaddingOf(context).bottom,
                ),
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
                        label: l10n.infoLocationOpen,
                        onTap: () => _openMap(context, ref, metadata),
                        trailing: _CopyButton(
                          text: formatCoordinates(
                            metadata.latitude!,
                            metadata.longitude!,
                          ),
                        ),
                      )
                    else if (info != null && !info.locationAllowed)
                      _InfoRow(
                        icon: Icons.location_off_outlined,
                        value: l10n.infoLocationNotAllowed,
                        muted: true,
                      ),
                    if (metadata case final metadata? when metadata.hasLocation)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(40, 4, 0, 12),
                        child: MiniMap(
                          point: (
                            latitude: metadata.latitude!,
                            longitude: metadata.longitude!,
                          ),
                        ),
                      ),
                    if (!item.isVideo)
                      if (ref.watch(photoQualityProvider(item)).value
                          case final quality?)
                        _InfoRow(
                          icon: Icons.blur_on_rounded,
                          value: formatQuality(quality),
                          label: switch ((
                            isBlurry(
                              sharpness: quality.sharpness,
                              contrast: quality.contrast,
                            ),
                            quality.brightness < darkBelow,
                          )) {
                            (true, _) => l10n.infoQualityBlurry,
                            (_, true) => l10n.infoQualityDark,
                            _ => l10n.infoQuality,
                          },
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
      ),
    );
  }
}

/// Lets the user close the panel by pulling it down from the top of its
/// content: the panel follows the finger, then closes past
/// [_dismissDistance] or on a downward fling, and slides back otherwise.
///
/// The sheet's own drag cannot do it, since the scroll view inside takes
/// every vertical drag; this listens to its overscroll instead.
class _PullToDismiss extends StatefulWidget {
  const _PullToDismiss({required this.child});

  final Widget child;

  @override
  State<_PullToDismiss> createState() => _PullToDismissState();
}

/// Pull distance that closes the panel, in logical pixels.
const _dismissDistance = 96.0;

/// Downward fling speed that closes the panel, in logical pixels per second.
const _dismissVelocity = 700.0;

class _PullToDismissState extends State<_PullToDismiss>
    with SingleTickerProviderStateMixin {
  /// How far the panel is pulled down; animated back to 0 on release.
  late final _offset = AnimationController.unbounded(vsync: this);
  bool _closing = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (_closing) return false;
    switch (notification) {
      // Pulling down past the top of the content.
      case OverscrollNotification(:final overscroll, dragDetails: _?)
          when overscroll < 0 || _offset.value > 0:
        _offset.value = (_offset.value - overscroll).clamp(0, double.infinity);
      // Moving the finger back up while pulled: the panel goes up first.
      case ScrollUpdateNotification(:final scrollDelta?, dragDetails: _?)
          when _offset.value > 0 && scrollDelta > 0:
        _offset.value = (_offset.value - scrollDelta).clamp(0, double.infinity);
      case ScrollEndNotification(:final dragDetails) when _offset.value > 0:
        final velocity = dragDetails?.primaryVelocity ?? 0;
        if (_offset.value > _dismissDistance || velocity > _dismissVelocity) {
          _closing = true;
          Navigator.of(context).pop();
        } else {
          _offset.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
        }
      default:
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: AnimatedBuilder(
        animation: _offset,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, _offset.value), child: child),
        child: widget.child,
      ),
    );
  }
}

/// Opens the map app at the location of [metadata]; when there is none,
/// closes the panel and says so.
Future<void> _openMap(
  BuildContext context,
  WidgetRef ref,
  MediaMetadata metadata,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final message = AppLocalizations.of(context).infoNoMapApp;
  final opened = await ref
      .read(platformBridgeProvider)
      .openMap(metadata.latitude!, metadata.longitude!);
  if (opened) return;
  // A snack bar would show under the panel.
  navigator.pop();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

/// The analysis engine's measures, as `S 42 · N 180 · B 35 · C 22`:
/// sharpness, relative sharpness, brightness and contrast
/// ([analysis-engine.md](../../../docs/analysis-engine.md)).
String formatQuality(ImageQuality quality) {
  final relative = relativeSharpness(
    sharpness: quality.sharpness,
    contrast: quality.contrast,
  );
  return [
    'S ${quality.sharpness.round()}',
    'N ${relative.round()}',
    'B ${quality.brightness.round()}',
    'C ${quality.contrast.round()}',
  ].join(' · ');
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
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String value;
  final String? label;

  /// Grey text: a note rather than a value.
  final bool muted;

  /// Called when the row is tapped; the value then reads as a link.
  final VoidCallback? onTap;

  /// Shown at the end of the row, e.g. a copy button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final link = Theme.of(context).colorScheme.primary;
    final style = switch ((muted, onTap)) {
      (true, _) => textTheme.bodyMedium?.copyWith(color: Colors.white70),
      (_, null) => textTheme.bodyLarge?.copyWith(color: Colors.white),
      _ => textTheme.bodyLarge?.copyWith(
        color: link,
        decoration: TextDecoration.underline,
        decorationColor: link,
      ),
    };
    final row = Padding(
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
                Text(value, style: style),
                if (label case final label?)
                  Text(
                    label,
                    style: textTheme.bodySmall?.copyWith(color: Colors.white60),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}

/// Copies [text] to the clipboard; shows a check for a moment after.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).infoCopy,
    color: Colors.white70,
    visualDensity: VisualDensity.compact,
    onPressed: _copy,
    icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
  );
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
