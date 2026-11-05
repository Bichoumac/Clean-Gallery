import 'dart:async';

import 'package:clean_gallery/core/media/media_formatting.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/features/monetization/monetization_controller.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Space a cleanup must free for the offer to appear (500 MB).
const int removeAdsOfferThreshold = 500 * 1024 * 1024;

/// After [freedBytes] were deleted for good, offers *Remove ads*: at most
/// once ever, and only with a price from the store.
Future<void> offerRemoveAdsAfterCleanup(
  BuildContext context,
  WidgetRef ref,
  int freedBytes,
) async {
  if (freedBytes <= removeAdsOfferThreshold) return;
  final state = ref.read(monetizationProvider);
  final price = state.price;
  if (state.adFree || state.phase == AdsPhase.off || price == null) return;
  final settings = ref.read(appSettingsControllerProvider.notifier);
  if (ref.read(appSettingsControllerProvider).removeAdsOfferShown) return;
  // Recorded first: closing the sheet in any way counts as dismissing it.
  await settings.setRemoveAdsOfferShown();
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final buy = await showModalBottomSheet<bool>(
    context: context,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.removeAdsOfferTitle(formatBytes(context, freedBytes)),
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(l10n.removeAdsOfferBody(price)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.removeAdsLink),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.removeAdsOfferDismiss),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (buy ?? false) {
    unawaited(ref.read(monetizationProvider.notifier).buy());
  }
}
