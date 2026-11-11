import 'package:clean_gallery/core/media/duplicates_tile.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/features/duplicates/duplicates_screen.dart';
import 'package:clean_gallery/features/viewer/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();

  // Two identical camera photos (one a favorite) and a third, different one.
  FakeMediaSource source() {
    final media = FakeMediaSource(
      items: [
        testItem(1, takenAt: now, sizeBytes: 2000000),
        testItem(2, takenAt: now, sizeBytes: 2000000, isFavorite: true),
        testItem(3, takenAt: now, sizeBytes: 900),
      ],
    );
    media.hashes
      ..['1'] = 'same'
      ..['2'] = 'same';
    return media;
  }

  Future<void> openDuplicates(WidgetTester tester) async {
    await tester.tap(find.byType(DuplicatesTile));
    await tester.pumpAndSettle();
  }

  testApp('the tile counts items to review and opens the screen', (
    tester,
  ) async {
    await pumpTestApp(tester, media: source());
    expect(find.text('Duplicates'), findsOneWidget);
    expect(find.textContaining('1 item to review'), findsOneWidget);

    await openDuplicates(tester);
    expect(find.byType(DuplicatesScreen), findsOneWidget);
    expect(find.text('Identical copies'), findsOneWidget);
    expect(find.text('Best'), findsOneWidget);
    expect(find.text('Move 1 to trash'), findsOneWidget);
    // Each copy shows where it is.
    expect(find.text('DCIM/Camera/IMG_1.jpg'), findsOneWidget);
    expect(find.text('DCIM/Camera/IMG_2.jpg'), findsOneWidget);
  });

  testApp('the duplicate period applies to the tile and the screen', (
    tester,
  ) async {
    // Issue #19.
    await pumpTestApp(tester, media: source());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DuplicatesTile)),
    );
    final settings = container.read(appSettingsControllerProvider.notifier);

    // A period before the photos: nothing to review anywhere.
    await settings.setDuplicatePeriod(DateFilter(end: DateTime(2001)));
    await tester.pumpAndSettle();
    expect(find.textContaining('to review'), findsNothing);

    // A period holding them: the copies are back, and the screen says why
    // other dates are left out.
    await settings.setDuplicatePeriod(
      DateFilter(start: DateTime(now.year, now.month, now.day)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1 item to review'), findsOneWidget);
    await openDuplicates(tester);
    expect(find.textContaining('Period: '), findsOneWidget);
    expect(find.textContaining('– today'), findsOneWidget);
    expect(find.text('Identical copies'), findsOneWidget);

    // Its cross goes back to the whole library.
    await tester.tap(find.byTooltip('Whole library'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Period: '), findsNothing);
    expect(
      container.read(appSettingsControllerProvider).duplicatePeriod,
      isNull,
    );
    expect(find.text('Identical copies'), findsOneWidget);
  });

  testApp('no tile without duplicates', (tester) async {
    await pumpTestApp(tester, media: FakeMediaSource(items: [testItem(1)]));
    expect(find.byType(DuplicatesTile), findsOneWidget);
    expect(find.text('Duplicates'), findsNothing);
  });

  testApp('clean all trashes the extra copy and keeps the best', (
    tester,
  ) async {
    await pumpTestApp(tester, media: source());
    await openDuplicates(tester);
    await tester.tap(find.text('Clean all groups'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Move 1 item'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Move to trash'));
    await tester.pumpAndSettle();

    expect(find.text('No duplicates'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DuplicatesScreen)),
    );
    // The favorite is kept; the other copy is in the trash.
    expect(await container.read(trashedIdsProvider.future), {'1'});
  });

  testApp('keeping every copy disables the group button', (tester) async {
    await pumpTestApp(tester, media: source());
    await openDuplicates(tester);
    await tester.tap(find.byTooltip('Keep'));
    await tester.pumpAndSettle();
    final button = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Move 0 to trash'),
        matching: find.byWidgetPredicate((w) => w is TextButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Clean all groups'), findsNothing);
  });

  testApp('tapping a photo opens it full screen', (tester) async {
    await pumpTestApp(tester, media: source());
    await openDuplicates(tester);
    await tester.tap(find.text('Best'));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget);
    expect(find.text('IMG_2.jpg'), findsOneWidget);
  });
}
