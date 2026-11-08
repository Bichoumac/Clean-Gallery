import 'dart:async';

import 'package:clean_gallery/core/config/app_config.dart';
import 'package:clean_gallery/platform/ads_service.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// [AdsService] on AdMob and Google's User Messaging Platform.
final class AndroidAdsService implements AdsService {
  /// Empty on purpose: no keyword and no content URL, ever.
  static const _request = AdRequest();

  InterstitialAd? _interstitial;

  @override
  bool get configured =>
      AppConfig.bannerAdUnitId.isNotEmpty &&
      AppConfig.nativeAdUnitId.isNotEmpty;

  @override
  Future<bool> gatherConsent() async {
    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      updated.complete,
      (_) => updated.complete(),
    );
    await updated.future;
    final dismissed = Completer<void>();
    await ConsentForm.loadAndShowConsentFormIfRequired((_) {
      if (!dismissed.isCompleted) dismissed.complete();
    });
    await dismissed.future;
    // After a failed update this is still the answer of the last session.
    return await ConsentInformation.instance.canRequestAds();
  }

  @override
  Future<void> initialize() => MobileAds.instance.initialize();

  @override
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<bool> showPrivacyOptions() async {
    final dismissed = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((_) {
      if (!dismissed.isCompleted) dismissed.complete();
    });
    await dismissed.future;
    return await ConsentInformation.instance.canRequestAds();
  }

  @override
  Future<LoadedAd?> loadBanner() async {
    final result = Completer<LoadedAd?>();
    final banner = BannerAd(
      adUnitId: AppConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: _request,
      listener: BannerAdListener(
        onAdLoaded: (ad) => result.complete(_LoadedAd(ad as AdWithView)),
        onAdFailedToLoad: (ad, _) {
          unawaited(ad.dispose());
          result.complete(null);
        },
      ),
    );
    await banner.load();
    return await result.future;
  }

  @override
  Future<LoadedAd?> loadNative(NativeAdColors colors) async {
    NativeTemplateTextStyle text(Color color, Color background) =>
        NativeTemplateTextStyle(textColor: color, backgroundColor: background);
    final result = Completer<LoadedAd?>();
    final native = NativeAd(
      adUnitId: AppConfig.nativeAdUnitId,
      request: _request,
      listener: NativeAdListener(
        onAdLoaded: (ad) => result.complete(_LoadedAd(ad as AdWithView)),
        onAdFailedToLoad: (ad, _) {
          unawaited(ad.dispose());
          result.complete(null);
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: colors.background,
        primaryTextStyle: text(colors.text, colors.background),
        secondaryTextStyle: text(colors.mutedText, colors.background),
        tertiaryTextStyle: text(colors.mutedText, colors.background),
        callToActionTextStyle: text(colors.buttonText, colors.button),
      ),
    );
    await native.load();
    return await result.future;
  }

  @override
  Future<void> preloadInterstitial() async {
    final unit = AppConfig.interstitialAdUnitId;
    if (unit.isEmpty || _interstitial != null) return;
    await InterstitialAd.load(
      adUnitId: unit,
      request: _request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  @override
  Future<void> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    final closed = Completer<void>();
    void finish(InterstitialAd ad) {
      unawaited(ad.dispose());
      if (!closed.isCompleted) closed.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: finish,
      onAdFailedToShowFullScreenContent: (ad, _) => finish(ad),
    );
    await ad.show();
    await closed.future;
  }
}

final class _LoadedAd implements LoadedAd {
  _LoadedAd(this._ad);

  final AdWithView _ad;

  @override
  Widget get view => AdWidget(ad: _ad);

  @override
  void dispose() => unawaited(_ad.dispose());
}
