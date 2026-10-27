import 'package:clean_gallery/analysis/similarity.dart';
import 'package:clean_gallery/core/database/settings_repository.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  test('a fresh install has the default settings', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final settings = await SettingsRepository(db).loadAppSettings();
    expect(settings, const AppSettings());
    expect(settings.trashRetentionDays, 30);
    expect(settings.removeGpsOnShare, isTrue);
    expect(settings.defaultColumns, 4);
  });

  test('stored values are read back', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final repository = SettingsRepository(db);
    await repository.write(SettingKeys.trashRetentionDays, '7');
    await repository.write(SettingKeys.removeGpsOnShare, 'false');
    await repository.write(SettingKeys.defaultColumns, '3');
    await repository.write(SettingKeys.theme, 'dark');
    await repository.write(SettingKeys.language, 'french');
    await repository.write('${SettingKeys.viewSortPrefix}photos:', 'size:desc');
    final settings = await repository.loadAppSettings();
    expect(settings.trashRetentionDays, 7);
    expect(settings.removeGpsOnShare, isFalse);
    expect(settings.defaultColumns, 3);
    expect(settings.theme, ThemePreference.dark);
    expect(settings.language, LanguagePreference.french);
    expect(
      settings.viewSorts['photos:'],
      const MediaSort(field: MediaSortField.size),
    );
  });

  test('invalid stored values fall back to defaults', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final repository = SettingsRepository(db);
    await repository.write(SettingKeys.trashRetentionDays, '500');
    await repository.write(SettingKeys.defaultColumns, 'many');
    await repository.write(SettingKeys.theme, 'purple');
    await repository.write('${SettingKeys.viewSortPrefix}videos:', 'oops');
    final settings = await repository.loadAppSettings();
    expect(settings.trashRetentionDays, 30);
    expect(settings.defaultColumns, 4);
    expect(settings.theme, ThemePreference.system);
    expect(settings.viewSorts, isEmpty);
  });

  test('similarity settings are read back, out of range ones not', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final repository = SettingsRepository(db);
    expect(
      (await repository.loadAppSettings()).similarityThresholds,
      SimilarityThresholds.medium,
    );
    await repository.write(SettingKeys.similaritySensitivity, 'custom');
    await repository.write(SettingKeys.similarityStrict, '3');
    await repository.write(SettingKeys.similarityLoose, '99');
    await repository.write(SettingKeys.similarityWindow, '20');
    final settings = await repository.loadAppSettings();
    expect(
      settings.similarityThresholds,
      const SimilarityThresholds(
        strict: 3,
        loose: 12,
        window: Duration(seconds: 20),
      ),
    );
    await repository.write(SettingKeys.similaritySensitivity, 'high');
    expect(
      (await repository.loadAppSettings()).similarityThresholds,
      SimilarityThresholds.high,
    );
  });

  test('cleanup thresholds are read back, invalid ones not', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final repository = SettingsRepository(db);
    expect((await repository.loadAppSettings()).screenshotAgeDays, 30);
    expect((await repository.loadAppSettings()).largeVideoMegabytes, 100);

    await repository.write(SettingKeys.screenshotAgeDays, '90');
    await repository.write(SettingKeys.largeVideoMegabytes, '250');
    var settings = await repository.loadAppSettings();
    expect(settings.screenshotAgeDays, 90);
    expect(settings.largeVideoMegabytes, 250);

    await repository.write(SettingKeys.screenshotAgeDays, '0');
    await repository.write(SettingKeys.largeVideoMegabytes, 'big');
    settings = await repository.loadAppSettings();
    expect(settings.screenshotAgeDays, 30);
    expect(settings.largeVideoMegabytes, 100);
  });

  test('sorts round-trip through their text form', () {
    for (final field in MediaSortField.values) {
      for (final descending in [true, false]) {
        final sort = MediaSort(field: field, descending: descending);
        expect(decodeSort(encodeSort(sort)), sort);
      }
    }
    expect(decodeSort('date'), isNull);
    expect(decodeSort('weight:desc'), isNull);
  });

  test('view keys tell tabs and folders apart', () {
    expect(viewKey(MediaSelection.photos), 'photos:');
    expect(viewKey(const MediaSelection(albumId: '42')), 'all:42');
  });
}
