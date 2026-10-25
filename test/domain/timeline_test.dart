import 'package:clean_gallery/domain/timeline.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  final items = [
    testItem(1, takenAt: DateTime(2026, 10, 25, 18)),
    testItem(2, takenAt: DateTime(2026, 10, 25, 8)),
    testItem(3, takenAt: DateTime(2026, 10, 24, 23, 59)),
    testItem(4, takenAt: DateTime(2026, 9, 30, 12)),
    testItem(5, takenAt: DateTime(2025, 9, 30, 12)),
  ];

  group('groupByDate', () {
    test('one section per day, in order', () {
      final sections = groupByDate(items, TimelineGrouping.day);
      expect(sections.map((s) => s.date), [
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 24),
        DateTime(2026, 9, 30),
        DateTime(2025, 9, 30),
      ]);
      expect(sections.map((s) => (s.start, s.length)), [
        (0, 2),
        (2, 1),
        (3, 1),
        (4, 1),
      ]);
    });

    test('one section per month; same month of another year is separate', () {
      final sections = groupByDate(items, TimelineGrouping.month);
      expect(sections.map((s) => s.date), [
        DateTime(2026, 10),
        DateTime(2026, 9),
        DateTime(2025, 9),
      ]);
      expect(sections.first.length, 3);
    });

    test('empty list gives no section', () {
      expect(groupByDate(const [], TimelineGrouping.day), isEmpty);
    });
  });

  group('buildRows', () {
    test('header then rows of at most `columns` items', () {
      final many = List.generate(
        7,
        (i) => testItem(i, takenAt: DateTime(2026, 10, 25, 12, i)),
      );
      final rows = buildRows(groupByDate(many, TimelineGrouping.day), 3);
      expect(rows.first, isA<TimelineHeader>());
      final itemRows = rows.whereType<TimelineItems>().toList();
      expect(itemRows.map((r) => (r.start, r.length)), [
        (0, 3),
        (3, 3),
        (6, 1),
      ]);
    });

    test('a row never spans two sections', () {
      final rows = buildRows(groupByDate(items, TimelineGrouping.day), 4);
      expect(rows.whereType<TimelineHeader>(), hasLength(4));
      expect(rows.whereType<TimelineItems>().map((r) => r.length), [
        2,
        1,
        1,
        1,
      ]);
    });
  });

  test('day headers up to 4 columns, month headers from 5', () {
    expect(groupingForColumns(2), TimelineGrouping.day);
    expect(groupingForColumns(4), TimelineGrouping.day);
    expect(groupingForColumns(5), TimelineGrouping.month);
    expect(groupingForColumns(6), TimelineGrouping.month);
  });
}
