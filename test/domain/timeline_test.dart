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

  group('buildCells', () {
    // 1 to 6 on one day, newest first; 7 the day before.
    final day = [
      for (var i = 1; i <= 6; i++)
        testItem(i, takenAt: DateTime(2026, 10, 25, 18, 60 - i)),
      testItem(7, takenAt: DateTime(2026, 10, 24, 23, 59)),
    ];
    List<(int, int, int)> spans(List<TimelineCell> cells) => [
      for (final c in cells) (c.start, c.length, c.cover),
    ];

    test('without groups, one cell per item', () {
      final cells = buildCells(day);
      expect(cells, hasLength(7));
      expect(cells.every((c) => c.stack == null && !c.folded), isTrue);
    });

    test('a run of one group folds into one cell showing its best', () {
      final cells = buildCells(
        day,
        stackOf: {'2': 'a', '3': 'a', '4': 'a'},
        coverOf: {'a': '3'},
      );
      expect(spans(cells), [
        (0, 1, 0),
        (1, 3, 2),
        (4, 1, 4),
        (5, 1, 5),
        (6, 1, 6),
      ]);
      final stack = cells[1];
      expect(stack.folded, isTrue);
      expect(stack.leads, isTrue);
      expect(stack.stackSize, 3);
      expect(stack.stack, 'a');
    });

    test('a run without the best shows its first item', () {
      final cells = buildCells(
        day,
        stackOf: {'1': 'a', '2': 'a', '5': 'a'},
        coverOf: {'a': '5'},
      );
      // 1 and 2 follow each other; 5 stands alone, away from them.
      expect(spans(cells).take(2), [(0, 2, 0), (2, 1, 2)]);
      expect(cells[4].stack, isNull);
    });

    test('only consecutive items stack; a single member stays alone', () {
      final cells = buildCells(day, stackOf: {'1': 'a', '3': 'a'});
      expect(cells, hasLength(7));
      expect(cells.every((c) => c.stack == null), isTrue);
    });

    test('two groups side by side make two stacks', () {
      final cells = buildCells(
        day,
        stackOf: {'1': 'a', '2': 'a', '3': 'b', '4': 'b'},
      );
      expect(spans(cells).take(2), [(0, 2, 0), (2, 2, 2)]);
    });

    test('a stack never crosses midnight', () {
      final cells = buildCells(day, stackOf: {'5': 'a', '6': 'a', '7': 'a'});
      expect(spans(cells).skip(4), [(4, 2, 4), (6, 1, 6)]);
      expect(cells.last.stack, isNull);
    });

    test('an unfolded stack shows each item, its cover leading', () {
      final cells = buildCells(
        day,
        stackOf: {'2': 'a', '3': 'a', '4': 'a'},
        coverOf: {'a': '3'},
        unfolded: {'a'},
      );
      expect(cells, hasLength(7));
      expect(cells.sublist(1, 4).map((c) => (c.stack, c.leads, c.folded)), [
        ('a', false, false),
        ('a', true, false),
        ('a', false, false),
      ]);
      expect(cells[1].stackSize, 3);
    });
  });

  test('day headers up to 4 columns, month headers from 5', () {
    expect(groupingForColumns(2), TimelineGrouping.day);
    expect(groupingForColumns(4), TimelineGrouping.day);
    expect(groupingForColumns(5), TimelineGrouping.month);
    expect(groupingForColumns(6), TimelineGrouping.month);
  });
}
