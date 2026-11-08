import 'dart:async';

import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:clean_gallery/features/monetization/monetization_controller.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:clean_gallery/platform/ads_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The native ad of the Stats tab: a tile of the mosaic labeled *Ad*, never
/// in the accent color.
///
/// Allowed only in the Stats tab (rule 3 of `AGENTS.md`, a test enforces
/// it). The space is reserved while it loads, and given back only when no
/// ad comes.
class NativeAdCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const NativeAdCard({super.key});

  /// Height of the small native template inside the tile.
  static const adHeight = 120.0;

  /// The small native template needs at least this width.
  static const minWidth = 320.0;

  @override
  ConsumerState<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends ConsumerState<NativeAdCard> {
  LoadedAd? _ad;
  bool _loading = false;
  bool _failed = false;
  Brightness? _brightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_brightness == null || brightness == _brightness) {
      _brightness = brightness;
      return;
    }
    // The template takes its colors when it loads.
    _brightness = brightness;
    _ad?.dispose();
    _ad = null;
    _failed = false;
  }

  Future<void> _load(ColorScheme colors) async {
    if (_loading || _ad != null || _failed) return;
    _loading = true;
    LoadedAd? ad;
    try {
      ad = await ref
          .read(adsServiceProvider)
          .loadNative(
            NativeAdColors(
              background: colors.surfaceContainerLow,
              text: colors.onSurface,
              mutedText: colors.onSurfaceVariant,
              button: colors.surfaceContainerHighest,
              buttonText: colors.onSurface,
            ),
          );
    } on Exception {
      ad = null;
    }
    _loading = false;
    if (!mounted) {
      ad?.dispose();
      return;
    }
    setState(() {
      _ad = ad;
      _failed = ad == null;
    });
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final phase = ref.watch(monetizationProvider.select((s) => s.phase));
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_failed || constraints.maxWidth < NativeAdCard.minWidth) {
          return const SizedBox.shrink();
        }
        if (phase == AdsPhase.ready && _ad == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_load(colors));
          });
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
              side: BorderSide(color: colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text(
                    AppLocalizations.of(context).adLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(height: NativeAdCard.adHeight, child: _ad?.view),
              ],
            ),
          ),
        );
      },
    );
  }
}
