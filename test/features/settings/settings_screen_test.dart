import 'package:clean_gallery/core/database/settings_repository.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  ThemeMode themeMode(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

  testApp('choosing Dark switches the app theme and is saved', (tester) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await pumpTestApp(tester, database: db);
    await openSettings(tester);
    expect(themeMode(tester), ThemeMode.system);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(themeMode(tester), ThemeMode.dark);
    expect(await SettingsRepository(db).read(SettingKeys.theme), 'dark');
  });

  testApp('choosing Français switches the language', (tester) async {
    await pumpTestApp(tester);
    await openSettings(tester);
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(find.text('Paramètres'), findsOneWidget);
  });

  testApp('default columns apply to the grid and are saved', (tester) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await pumpTestApp(tester, database: db);
    await openSettings(tester);
    await tester.ensureVisible(find.text('Grid columns at launch'));
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<int>),
        matching: find.text('2'),
      ),
    );
    await tester.pumpAndSettle();
    expect(await SettingsRepository(db).read(SettingKeys.defaultColumns), '2');
  });

  testApp('corrected dates can be turned off and are saved', (tester) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final received = testItem(
      1,
      takenAt: DateTime(2026, 9, 1, 8),
    ).copyWith(fileName: 'IMG-20240315-WA0001.jpg');
    final media = FakeMediaSource(items: [received])
      ..withoutMetadataDate.add('1');
    await pumpTestApp(tester, media: media, database: db);
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All media'));
    await tester.pumpAndSettle();
    DateTime shownDate() =>
        tester.widget<MediaThumbnail>(find.byType(MediaThumbnail)).item.takenAt;
    expect(shownDate(), DateTime(2024, 3, 15, 12));

    await openSettings(tester);
    await tester.ensureVisible(find.text('Corrected dates'));
    await tester.tap(find.text('Corrected dates'));
    await tester.pumpAndSettle();
    expect(
      await SettingsRepository(db).read(SettingKeys.correctedDates),
      'false',
    );

    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    expect(shownDate(), DateTime(2026, 9, 1, 8));
  });

  testApp('analyzing again reads the duplicates again', (tester) async {
    final media = FakeMediaSource(
      items: [testItem(1, sizeBytes: 50), testItem(2, sizeBytes: 50)],
    );
    await pumpTestApp(tester, media: media);
    expect(media.hashCalls, hasLength(1));
    final describes = media.describeCalls.length;

    await openSettings(tester);
    await tester.scrollUntilVisible(
      find.text('Analyze the library again'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    // At the top of the page, clear of the floating navigation bar.
    await tester.ensureVisible(find.text('Analyze the library again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyze the library again'));
    await tester.pumpAndSettle();
    expect(
      find.text('Analysis started. Lists update as it goes.'),
      findsOneWidget,
    );
    expect(media.hashCalls, hasLength(2));
    expect(media.describeCalls.length, greaterThan(describes));
  });

  testApp('similar photo sensitivity and advanced mode are saved', (
    tester,
  ) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await pumpTestApp(tester, database: db);
    await openSettings(tester);
    final repository = SettingsRepository(db);

    /// Scrolls [text] to the top of the page, clear of the floating
    /// navigation bar.
    Future<void> reveal(String text) async {
      await tester.scrollUntilVisible(
        find.text(text),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
    }

    await reveal('High');
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();
    expect(await repository.read(SettingKeys.similaritySensitivity), 'high');
    expect(find.text('Any date: difference up to'), findsNothing);
    // Issue #19: the presets read as tolerance thresholds.
    expect(find.text('Similar photos: tolerance threshold'), findsOneWidget);
    expect(find.textContaining('High tolerance:'), findsOneWidget);

    await reveal('Advanced mode');
    await tester.tap(find.text('Advanced mode'));
    await tester.pumpAndSettle();
    expect(await repository.read(SettingKeys.similaritySensitivity), 'custom');
    // The advanced mode starts from the preset in use.
    expect(await repository.read(SettingKeys.similarityStrict), '10');
    expect(find.text('Any date: difference up to'), findsOneWidget);
    expect(find.text('10 / 64'), findsOneWidget);
    expect(find.text('10 minutes'), findsOneWidget);
    expect(await repository.read(SettingKeys.similarityWindow), '600');

    await reveal('Advanced mode');
    await tester.tap(find.text('Advanced mode'));
    await tester.pumpAndSettle();
    expect(await repository.read(SettingKeys.similaritySensitivity), 'medium');
  });

  testApp('the duplicate period is picked, saved and reset', (tester) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await pumpTestApp(tester, database: db);
    await openSettings(tester);
    final repository = SettingsRepository(db);

    await tester.scrollUntilVisible(
      find.text('To'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    // In the middle of the page, clear of the floating navigation bar.
    await Scrollable.ensureVisible(
      tester.element(find.text('From')),
      alignment: 0.4,
    );
    await tester.pumpAndSettle();
    expect(find.text('Period analyzed'), findsOneWidget);
    expect(find.text('the beginning'), findsOneWidget);
    expect(find.text('Whole library'), findsNothing);

    // From: today, as the calendar opens on it.
    await tester.tap(find.text('From'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(
      await repository.read(SettingKeys.duplicatePeriodStart),
      isoDay(now),
    );
    expect(await repository.read(SettingKeys.duplicatePeriodEnd), '');
    expect(find.text('the beginning'), findsNothing);

    await Scrollable.ensureVisible(
      tester.element(find.text('Whole library')),
      alignment: 0.4,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Whole library'));
    await tester.pumpAndSettle();
    expect(await repository.read(SettingKeys.duplicatePeriodStart), '');
    expect(find.text('the beginning'), findsOneWidget);
  });

  testApp('permission statuses are shown', (tester) async {
    final permissions = FakePermissionService(result: MediaAccess.limited)
      ..locationGranted = false;
    final bridge = FakePlatformBridge()..mediaManagementGranted = true;
    await pumpTestApp(tester, permissions: permissions, bridge: bridge);
    await openSettings(tester);
    await tester.scrollUntilVisible(
      find.text('Media management'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Some items only'), findsOneWidget);
    expect(find.text('Not allowed'), findsOneWidget);
    expect(find.text('Allowed'), findsOneWidget);
  });

  testApp('the sort of a tab is restored at the next launch', (tester) async {
    final now = DateTime.now();
    final media = FakeMediaSource(
      items: [
        testItem(1, takenAt: now),
        testItem(2, takenAt: now.subtract(const Duration(days: 1))),
      ],
    );
    await pumpTestApp(
      tester,
      media: media,
      settings: const AppSettings(
        viewSorts: {'camera:': MediaSort(descending: false)},
      ),
    );
    final ids = tester
        .widgetList<MediaThumbnail>(find.byType(MediaThumbnail))
        .map((t) => t.item.id)
        .toList();
    expect(ids, ['2', '1']);
    expect(find.text('Date · Oldest first'), findsOneWidget);
  });

  testApp('changing the sort saves it', (tester) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await pumpTestApp(tester, database: db);
    await tester.tap(find.byTooltip('Sort and filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Size'));
    await tester.pumpAndSettle();
    expect(
      await SettingsRepository(db).read('${SettingKeys.viewSortPrefix}camera:'),
      'size:desc',
    );
  });
}
