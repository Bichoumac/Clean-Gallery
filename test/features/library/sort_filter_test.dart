import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/timeline.dart';
import 'package:clean_gallery/features/library/sort_filter_sheet.dart';
import 'package:clean_gallery/features/viewer/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  group('DateFilter', () {
    test('days() includes both days and excludes the next one', () {
      final range = DateFilter.days(
        DateTime(2026, 3, 12),
        DateTime(2026, 3, 20),
      );
      expect(range.contains(DateTime(2026, 3, 12)), isTrue);
      expect(range.contains(DateTime(2026, 3, 20, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 3, 21)), isFalse);
      expect(range.contains(DateTime(2026, 3, 11, 23, 59)), isFalse);
    });

    test('open ranges', () {
      final since = DateFilter(start: DateTime(2026));
      expect(since.contains(DateTime(2030)), isTrue);
      expect(since.contains(DateTime(2025, 12, 31)), isFalse);
    });
  });

  group('presets', () {
    final now = DateTime(2026, 10, 25, 15);

    test('ranges relative to today', () {
      expect(
        datePresetRange(DatePreset.last7Days, now),
        DateFilter(start: DateTime(2026, 10, 19), end: DateTime(2026, 10, 26)),
      );
      expect(
        datePresetRange(DatePreset.thisYear, now),
        DateFilter(start: DateTime(2026)),
      );
      expect(
        datePresetRange(DatePreset.lastYear, now),
        DateFilter(start: DateTime(2025), end: DateTime(2026)),
      );
    });

    test('a range is recognized as its preset', () {
      final range = datePresetRange(DatePreset.last30Days, now);
      expect(matchingPreset(range, now), DatePreset.last30Days);
      expect(matchingPreset(DateFilter(start: DateTime(2020)), now), isNull);
      expect(matchingPreset(null, now), isNull);
    });
  });

  test('buildFlatRows: rows of `columns` items, no header', () {
    final rows = buildFlatRows(7, 3);
    expect(rows.every((r) => r is TimelineItems), isTrue);
    expect(rows.cast<TimelineItems>().map((r) => (r.start, r.length)), [
      (0, 3),
      (3, 3),
      (6, 1),
    ]);
  });

  group('in the app', () {
    final now = DateTime.now();
    FakeMediaSource source() => FakeMediaSource(
      items: [
        testItem(1, takenAt: now),
        testItem(2, takenAt: now.subtract(const Duration(days: 2))),
        testItem(3, takenAt: DateTime(2020, 5)),
      ],
    );

    List<String> shownIds(WidgetTester tester) => tester
        .widgetList<MediaThumbnail>(find.byType(MediaThumbnail))
        .map((t) => t.item.id)
        .toList();

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Sort and filter'));
      await tester.pumpAndSettle();
    }

    Future<void> closeSheet(WidgetTester tester) async {
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }

    testWidgets('sorting by name removes date headers', (tester) async {
      await pumpTestApp(tester, media: source());
      expect(find.text('Today'), findsOneWidget);
      expect(shownIds(tester), ['1', '2', '3']);

      await openSheet(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Name'));
      await tester.pumpAndSettle();
      expect(find.text('A to Z'), findsOneWidget);
      await tester.tap(find.text('Z to A'));
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(find.text('Today'), findsNothing);
      expect(shownIds(tester), ['3', '2', '1']);
      expect(find.text('Name · Z to A'), findsOneWidget); // Active chip.
    });

    testWidgets('date preset hides older items; chip clears it', (
      tester,
    ) async {
      await pumpTestApp(tester, media: source());
      await openSheet(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Last 7 days'));
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(shownIds(tester), ['1', '2']);
      final chip = find.widgetWithText(InputChip, 'Last 7 days');
      expect(chip, findsOneWidget);

      await tester.tap(
        find.descendant(of: chip, matching: find.byTooltip('Delete')),
      );
      await tester.pumpAndSettle();
      expect(shownIds(tester), ['1', '2', '3']);
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('empty period offers to clear the filter', (tester) async {
      final media = FakeMediaSource(
        items: [testItem(3, takenAt: DateTime(2020, 5))],
      );
      await pumpTestApp(tester, media: media);
      await openSheet(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'This year'));
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(find.text('Nothing in this period'), findsOneWidget);
      await tester.tap(find.text('Clear filter'));
      await tester.pumpAndSettle();
      expect(shownIds(tester), ['3']);
    });

    testWidgets('the viewer follows the chosen order', (tester) async {
      await pumpTestApp(tester, media: source());
      await openSheet(tester);
      await tester.tap(find.text('Oldest first'));
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(shownIds(tester), ['3', '2', '1']);
      await tester.tap(find.byType(MediaThumbnail).first);
      await tester.pumpAndSettle();
      expect(find.byType(ViewerScreen), findsOneWidget);
      expect(find.text('IMG_3.jpg'), findsOneWidget);
    });

    testWidgets('each tab keeps its own order', (tester) async {
      await pumpTestApp(tester, media: source());
      await openSheet(tester);
      await tester.tap(find.text('Oldest first'));
      await tester.pumpAndSettle();
      await closeSheet(tester);

      await tester.tap(find.byTooltip('Albums'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All media'));
      await tester.pumpAndSettle();
      expect(shownIds(tester), ['1', '2', '3']);
    });
  });
}
