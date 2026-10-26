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
    // Clear of the floating navigation bar.
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
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
