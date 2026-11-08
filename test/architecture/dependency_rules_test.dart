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

  test('no ads, purchase or tracking SDK: the app is open source and '
      'free (ADR 0032)', () {
    final banned = RegExp(
      'google_mobile_ads|in_app_purchase|firebase|play_services_ads|'
      'facebook_audience|applovin|unity_ads',
    );
    expect(banned.hasMatch(File('pubspec.yaml').readAsStringSync()), isFalse);
    for (final file in dartFiles('lib')) {
      expect(
        banned.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }
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
