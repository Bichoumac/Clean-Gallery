import 'package:flutter/foundation.dart';

/// Build-time configuration: ad unit IDs and build flavor.
///
/// Production IDs are never committed. Release builds receive them through
/// `--dart-define`, for example:
///
/// ```sh
/// flutter build appbundle --release \
///   --dart-define=ADMOB_BANNER_UNIT_ID=ca-app-pub-xxx/yyy \
///   --dart-define=ADMOB_NATIVE_UNIT_ID=ca-app-pub-xxx/zzz \
///   -PadmobAppId=ca-app-pub-xxx~www
/// ```
///
/// Debug and profile builds always use Google's public test ad units. A
/// release build without an ID gets an empty string, and the ads feature
/// then stays off. See `docs/monetization.md`.
abstract final class AppConfig {
  /// Google's public test banner ad unit for Android.
  static const _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  /// Google's public test native ad unit for Android.
  static const _testNativeAdUnitId = 'ca-app-pub-3940256099942544/2247696110';

  static const _releaseBannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ID',
  );

  static const _releaseNativeAdUnitId = String.fromEnvironment(
    'ADMOB_NATIVE_UNIT_ID',
  );

  /// Whether this is a release build. Release builds never use test IDs.
  static bool get isReleaseBuild => kReleaseMode;

  /// Banner ad unit ID for the current build mode.
  static String get bannerAdUnitId =>
      isReleaseBuild ? _releaseBannerAdUnitId : _testBannerAdUnitId;

  /// Native ad unit ID for the current build mode.
  static String get nativeAdUnitId =>
      isReleaseBuild ? _releaseNativeAdUnitId : _testNativeAdUnitId;
}
