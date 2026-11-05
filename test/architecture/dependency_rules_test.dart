import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the layering rules from `docs/architecture.md` by scanning
/// imports, so a violation fails CI instead of slipping through review.
void main() {
  Iterable<File> dartFiles(String dir) =>
      Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

  List<String> violations(String dir, RegExp forbidden) => [
    for (final file in dartFiles(dir))
      for (final line in file.readAsLinesSync())
        if (line.startsWith('import ') && forbidden.hasMatch(line))
          '${file.path}: $line',
  ];

  test('analysis engine is pure Dart (no Flutter, no platform, no UI)', () {
    final forbidden = RegExp(
      "package:(flutter|flutter_riverpod|clean_gallery/(core|platform|features))[/']",
    );
    expect(violations('lib/analysis', forbidden), isEmpty);
  });

  test('domain layer does not depend on Flutter or other layers', () {
    final forbidden = RegExp(
      "package:(flutter|clean_gallery/(core|platform|features))[/']",
    );
    expect(violations('lib/domain', forbidden), isEmpty);
  });

  test('features never import Android implementations directly', () {
    final forbidden = RegExp('package:clean_gallery/platform/android/');
    expect(violations('lib/features', forbidden), isEmpty);
  });

  group('ads (rules 3 and 4 of AGENTS.md)', () {
    List<String> using(RegExp pattern) => [
      for (final file in dartFiles('lib'))
        if (!file.path.endsWith('.g.dart') &&
            pattern.hasMatch(file.readAsStringSync()))
          file.path.replaceAll(r'\', '/'),
    ];

    test('the SDKs are used only behind the platform interfaces', () {
      expect(using(RegExp('package:google_mobile_ads/')), [
        'lib/platform/android/android_ads_service.dart',
      ]);
      expect(using(RegExp('package:in_app_purchase')), [
        'lib/platform/android/android_purchase_service.dart',
      ]);
    });

    test('only a banner in Albums and a native card in Stats', () {
      expect(using(RegExp('monetization/ad_banner_slot.dart')), [
        'lib/features/library/albums_screen.dart',
      ]);
      expect(using(RegExp('monetization/native_ad_card.dart')), [
        'lib/features/stats/stats_screen.dart',
      ]);
    });

    test('no rewarded or app-open ad', () {
      expect(
        using(RegExp('RewardedAd|RewardedInterstitial|AppOpenAd')),
        isEmpty,
      );
    });

    test('a full-screen ad only before a manual slideshow', () {
      expect(using(RegExp(r'\bInterstitialAd\b')), [
        'lib/platform/android/android_ads_service.dart',
      ]);
      expect(using(RegExp(r'\.showInterstitial\(')), [
        'lib/features/monetization/monetization_controller.dart',
      ]);
      expect(using(RegExp(r'\.showSlideshowAd\(')), [
        'lib/features/slideshow/slideshow_actions.dart',
      ]);
      final source = File('lib/features/slideshow/slideshow_actions.dart')
          .readAsStringSync();
      // Only the two manual launches, not memories, rituals or saved ones.
      expect(RegExp(r'\.showSlideshowAd\(').allMatches(source), hasLength(2));
    });

    test('the ads Topics permission stays removed', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(
        RegExp(
          r'android\.permission\.ACCESS_ADSERVICES_TOPICS"\s+tools:node="remove"',
        ).hasMatch(manifest),
        isTrue,
      );
    });

    test('requests carry nothing about the user or their media', () {
      final source = File('lib/platform/android/android_ads_service.dart')
          .readAsStringSync();
      expect(source, contains('AdRequest()'));
      expect(
        RegExp('keywords|contentUrl|neighboringContentUrls|extras|MediaItem')
            .hasMatch(source),
        isFalse,
      );
    });
  });

  test('MANAGE_EXTERNAL_STORAGE is never declared', () {
    // Matches a permission declaration, not comments that mention the name.
    final declaration = RegExp(
      r'android:name="android\.permission\.MANAGE_EXTERNAL_STORAGE"',
    );
    final manifests = Directory('android/app/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('AndroidManifest.xml'));
    for (final manifest in manifests) {
      expect(
        declaration.hasMatch(manifest.readAsStringSync()),
        isFalse,
        reason: manifest.path,
      );
    }
  });

  test('notifications read neither photos nor the database (ADR 0027)', () {
    // The only code that runs while the app is closed: the alarm and boot
    // receiver. It may read its list of notifications, nothing else.
    final reminders = File(
      'android/app/src/main/kotlin/com/bichoumac/clean_gallery/Reminders.kt',
    ).readAsStringSync();
    final forbidden = RegExp(
      r'MediaStore|ContentResolver|contentResolver|SQLite|\.db\b|'
      r'clean_gallery\.sqlite|MediaIndex|FlutterEngine|WorkManager',
    );
    expect(forbidden.allMatches(reminders).map((m) => m[0]), isEmpty);
    expect(reminders, contains('class ReminderReceiver'));
  });
}
