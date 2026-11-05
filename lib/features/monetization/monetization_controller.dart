import 'dart:async';

import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/platform/purchase_service.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'monetization_controller.freezed.dart';
part 'monetization_controller.g.dart';

/// Whether ads can be shown.
enum AdsPhase {
  /// Waiting for the store and for consent: the space is reserved, nothing
  /// is loaded.
  starting,

  /// Consent is resolved and the SDK started: ads may load.
  ready,

  /// No ads: ad-free, no consent, or a build without ad unit IDs.
  off,
}

/// A message to show once about the purchase.
enum PurchaseMessage {
  /// The payment is pending.
  pending,

  /// Ads are gone.
  purchased,

  /// The purchase screen was closed.
  cancelled,

  /// The store reported an error or is unavailable.
  failed,

  /// A previous purchase was found.
  restored,

  /// The account has no purchase to restore.
  nothingToRestore,
}

/// What the screens need to know about ads and the purchase.
@freezed
abstract class MonetizationState with _$MonetizationState {
  /// Creates the state.
  const factory MonetizationState({
    required bool adFree,
    required AdsPhase phase,
    String? price,
    @Default(false) bool privacyOptionsRequired,
    PurchaseMessage? message,
  }) = _MonetizationState;
}

/// Runs the launch sequence and the purchase.
///
/// At launch: the store first, so an ad-free user never starts the ads SDK;
/// then consent; only then the SDK. See `docs/monetization.md`.
@Riverpod(keepAlive: true)
class Monetization extends _$Monetization {
  /// How long the launch waits for the store before using the cached answer.
  static const storeTimeout = Duration(seconds: 5);

  bool _started = false;

  @override
  MonetizationState build() {
    final subscription = ref
        .read(purchaseServiceProvider)
        .updates
        .listen((update) => unawaited(_onUpdate(update)));
    ref.onDispose(() => unawaited(subscription.cancel()));
    final adFree = ref.read(appSettingsControllerProvider).adFree;
    return MonetizationState(
      adFree: adFree,
      phase: adFree || !ref.read(adsServiceProvider).configured
          ? AdsPhase.off
          : AdsPhase.starting,
    );
  }

  /// Runs the launch sequence once. Call it after onboarding: the consent
  /// form never comes before the permission pages.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final owned = await _askStore();
    if (owned != null) await _saveAdFree(value: owned);
    if (!ref.read(adsServiceProvider).configured) return;
    if (!state.adFree) {
      unawaited(_loadPrice());
      await _startAds();
    }
  }

  Future<bool?> _askStore() async {
    try {
      return await ref
          .read(purchaseServiceProvider)
          .ownsRemoveAds()
          .timeout(storeTimeout, onTimeout: () => null);
    } on PlatformException {
      return null;
    }
  }

  Future<void> _loadPrice() async {
    try {
      final price = await ref.read(purchaseServiceProvider).removeAdsPrice();
      state = state.copyWith(price: price);
    } on PlatformException {
      // No price: the offers stay out of sight until the next launch.
    }
  }

  Future<void> _startAds() async {
    final ads = ref.read(adsServiceProvider);
    state = state.copyWith(phase: AdsPhase.starting);
    try {
      final allowed = await ads.gatherConsent();
      if (allowed && !state.adFree) await ads.initialize();
      final required = await ads.privacyOptionsRequired();
      state = state.copyWith(
        phase: allowed && !state.adFree ? AdsPhase.ready : AdsPhase.off,
        privacyOptionsRequired: required,
      );
    } on PlatformException {
      // Without an answer about consent, no ad is ever requested.
      state = state.copyWith(phase: AdsPhase.off);
    }
  }

  Future<void> _saveAdFree({required bool value}) async {
    final wasAdFree = state.adFree;
    state = state.copyWith(
      adFree: value,
      phase: value ? AdsPhase.off : state.phase,
    );
    if (wasAdFree != value) {
      await ref
          .read(appSettingsControllerProvider.notifier)
          .setAdFree(value: value);
    }
  }

  Future<void> _onUpdate(PurchaseUpdate update) async {
    switch (update) {
      case PurchaseUpdate.pending:
        state = state.copyWith(message: PurchaseMessage.pending);
      case PurchaseUpdate.purchased:
        await _saveAdFree(value: true);
        state = state.copyWith(message: PurchaseMessage.purchased);
      case PurchaseUpdate.cancelled:
        state = state.copyWith(message: PurchaseMessage.cancelled);
      case PurchaseUpdate.failed:
        state = state.copyWith(message: PurchaseMessage.failed);
      case PurchaseUpdate.alreadyOwned:
        await _saveAdFree(value: true);
        state = state.copyWith(message: PurchaseMessage.restored);
    }
  }

  /// Opens the store's purchase screen.
  Future<void> buy() async {
    bool opened;
    try {
      opened = await ref.read(purchaseServiceProvider).buyRemoveAds();
    } on PlatformException {
      opened = false;
    }
    if (opened) return;
    // Refused when already owned, among other reasons.
    if (await _askStore() ?? false) {
      await _saveAdFree(value: true);
      state = state.copyWith(message: PurchaseMessage.restored);
    } else {
      state = state.copyWith(message: PurchaseMessage.failed);
    }
  }

  /// Settings → *Restore purchase*.
  Future<void> restore() async {
    final owned = await _askStore();
    switch (owned) {
      case null:
        state = state.copyWith(message: PurchaseMessage.failed);
      case true:
        await _saveAdFree(value: true);
        state = state.copyWith(message: PurchaseMessage.restored);
      case false:
        final wasAdFree = state.adFree;
        await _saveAdFree(value: false);
        state = state.copyWith(message: PurchaseMessage.nothingToRestore);
        // Refunded since the last check: ads come back.
        if (wasAdFree && ref.read(adsServiceProvider).configured) {
          await _startAds();
        }
    }
  }

  /// Settings → *Privacy & ad choices*.
  Future<void> showPrivacyOptions() async {
    try {
      final allowed = await ref.read(adsServiceProvider).showPrivacyOptions();
      if (allowed && state.phase == AdsPhase.off && !state.adFree) {
        await _startAds();
      } else if (!allowed) {
        state = state.copyWith(phase: AdsPhase.off);
      }
    } on PlatformException {
      state = state.copyWith(message: PurchaseMessage.failed);
    }
  }

  /// The current message has been shown.
  void messageShown() => state = state.copyWith(message: null);
}
