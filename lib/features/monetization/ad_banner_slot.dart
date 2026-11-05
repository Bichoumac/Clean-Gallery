import 'dart:async';

import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/features/monetization/monetization_controller.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:clean_gallery/platform/ads_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The small banner of the Albums tab, with a discreet *Remove ads* link.
///
/// Allowed only at the bottom of the Albums tab (rule 3 of `AGENTS.md`, a
/// test enforces it). Its space is reserved before the ad loads and stays
/// when none comes, so the layout never jumps.
class AdBannerSlot extends ConsumerStatefulWidget {
  /// Creates the slot. The caller shows it only while ads are not off.
  const AdBannerSlot({super.key});

  /// Size of the standard banner, the smallest AdMob offers.
  static const bannerSize = Size(320, 50);

  @override
  ConsumerState<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends ConsumerState<AdBannerSlot> {
  /// A second try after a failed load; never more, to avoid hammering.
  static const _retryDelay = Duration(seconds: 60);

  LoadedAd? _ad;
  bool _loading = false;
  bool _retried = false;
  Timer? _retry;

  Future<void> _load() async {
    if (_loading || _ad != null) return;
    _loading = true;
    final ad = await _safely(() => ref.read(adsServiceProvider).loadBanner());
    _loading = false;
    if (!mounted) {
      ad?.dispose();
      return;
    }
    if (ad != null) {
      setState(() => _ad = ad);
    } else if (!_retried) {
      _retried = true;
      _retry = Timer(_retryDelay, () => unawaited(_load()));
    }
  }

  /// An ad that fails leaves the space empty; it never reaches the user.
  Future<T?> _safely<T>(Future<T?> Function() call) async {
    try {
      return await call();
    } on Exception {
      return null;
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(monetizationProvider);
    if (state.phase == AdsPhase.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _retry == null) unawaited(_load());
      });
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const Size(0, 28),
              textStyle: Theme.of(context).textTheme.labelSmall,
            ),
            onPressed: () =>
                unawaited(ref.read(monetizationProvider.notifier).buy()),
            child: Text(l10n.removeAdsLink),
          ),
        ),
        SizedBox.fromSize(size: AdBannerSlot.bannerSize, child: _ad?.view),
      ],
    );
  }
}
