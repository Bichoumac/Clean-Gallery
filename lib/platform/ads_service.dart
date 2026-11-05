import 'package:flutter/widgets.dart';

/// An ad that has been loaded and can be placed in the widget tree.
abstract interface class LoadedAd {
  /// Shows the ad. Place it at most once.
  Widget get view;

  /// Frees the ad. Call it when the ad leaves the screen.
  void dispose();
}

/// Colors of the native ad card, taken from the theme by the caller.
@immutable
class NativeAdColors {
  /// Creates the colors of a card.
  const NativeAdColors({
    required this.background,
    required this.text,
    required this.mutedText,
    required this.button,
    required this.buttonText,
  });

  /// Background of the card.
  final Color background;

  /// Headline.
  final Color text;

  /// Secondary lines.
  final Color mutedText;

  /// Background of the call to action.
  final Color button;

  /// Text of the call to action.
  final Color buttonText;
}

/// Consent, SDK start and the two allowed ad formats.
///
/// Requests never carry anything about the user's media: no keywords, no
/// content URL (rule 4 of `AGENTS.md`). See `docs/monetization.md`.
abstract interface class AdsService {
  /// Whether this build has ad unit IDs. A release without them has no ads.
  bool get configured;

  /// Updates the consent information and shows the form when it is required.
  /// Returns whether ads may be requested. Nothing is loaded before this.
  Future<bool> gatherConsent();

  /// Starts the ads SDK. Never called for an ad-free user.
  Future<void> initialize();

  /// Whether the law asks for a way to reopen the consent form.
  Future<bool> privacyOptionsRequired();

  /// Reopens the consent form. Returns whether ads may still be requested.
  Future<bool> showPrivacyOptions();

  /// Height of an adaptive banner [width] dp wide, to reserve its space
  /// before it loads; `null` when it cannot be worked out.
  Future<double?> bannerHeight(int width);

  /// Loads an adaptive banner; `null` when none could be loaded.
  Future<LoadedAd?> loadBanner(int width);

  /// Loads a native ad; `null` when none could be loaded.
  Future<LoadedAd?> loadNative(NativeAdColors colors);
}
