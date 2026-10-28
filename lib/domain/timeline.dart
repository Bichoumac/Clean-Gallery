import 'package:clean_gallery/domain/media_item.dart';

/// How a timeline groups its items.
enum TimelineGrouping {
  /// One section per calendar day.
  day,

  /// One section per calendar month.
  month,
}

/// A run of consecutive items sharing the same day or month.
final class TimelineSection {
  /// Creates a section starting at [date] (midnight, or the 1st of the month).
  const TimelineSection({
    required this.date,
    required this.start,
    required this.length,
  });

  /// First instant of the day or month of this section, in local time.
  final DateTime date;

  /// Index in the source list of the first item of this section.
  final int start;

  /// Number of items in this section.
  final int length;
}

/// One line of a timeline grid: either a section header or a row of items.
sealed class TimelineRow {
  const TimelineRow();
}

/// Header line above a section.
final class TimelineHeader extends TimelineRow {
  /// Creates a header for [section].
  const TimelineHeader(this.section);

  /// Section this header introduces.
  final TimelineSection section;
}

/// A line of up to `columns` items.
final class TimelineItems extends TimelineRow {
  /// Creates a row covering source indexes `[start, start + length)`.
  const TimelineItems({required this.start, required this.length});

  /// Index in the source list of the first item of the row.
  final int start;

  /// Number of items in the row, from 1 to the column count.
  final int length;
}

/// Splits [items], already sorted newest first, into date sections.
///
/// Items are compared in local time, so a photo taken at 23:30 belongs to
/// the day the user saw on their clock.
List<TimelineSection> groupByDate(
  List<MediaItem> items,
  TimelineGrouping grouping,
) {
  final sections = <TimelineSection>[];
  DateTime? current;
  var start = 0;
  for (var i = 0; i < items.length; i++) {
    final key = _bucket(items[i].takenAt.toLocal(), grouping);
    if (key != current) {
      if (current != null) {
        sections.add(
          TimelineSection(date: current, start: start, length: i - start),
        );
      }
      current = key;
      start = i;
    }
  }
  if (current != null) {
    sections.add(
      TimelineSection(
        date: current,
        start: start,
        length: items.length - start,
      ),
    );
  }
  return sections;
}

/// Flattens [sections] into header and item rows for a grid of [columns].
///
/// The result is what a lazy list renders, one row per index, so a timeline
/// of 30,000 items only builds the rows on screen.
List<TimelineRow> buildRows(List<TimelineSection> sections, int columns) {
  assert(columns > 0, 'columns must be positive');
  final rows = <TimelineRow>[];
  for (final section in sections) {
    rows.add(TimelineHeader(section));
    final end = section.start + section.length;
    for (var i = section.start; i < end; i += columns) {
      rows.add(TimelineItems(start: i, length: (end - i).clamp(1, columns)));
    }
  }
  return rows;
}

/// Rows of a grid without headers, for orders that are not chronological
/// (name, size, duration), where date sections would be meaningless.
List<TimelineRow> buildFlatRows(int itemCount, int columns) {
  assert(columns > 0, 'columns must be positive');
  return [
    for (var i = 0; i < itemCount; i += columns)
      TimelineItems(start: i, length: (itemCount - i).clamp(1, columns)),
  ];
}

/// Grouping used for a grid with [columns] columns: days while thumbnails
/// are large, months once the grid is dense.
TimelineGrouping groupingForColumns(int columns) =>
    columns <= 4 ? TimelineGrouping.day : TimelineGrouping.month;

DateTime _bucket(DateTime local, TimelineGrouping grouping) =>
    switch (grouping) {
      TimelineGrouping.day => DateTime(local.year, local.month, local.day),
      TimelineGrouping.month => DateTime(local.year, local.month),
    };

/// A cell of a timeline grid: one item, or a folded stack of consecutive
/// duplicates shown as one thumbnail (its cover).
///
/// A cell covers items `[start, start + length)` of the source list, so
/// cells keep the source order and selecting a folded stack selects every
/// item under it.
final class TimelineCell {
  /// Creates a cell over `[start, start + length)` showing [cover].
  const TimelineCell({
    required this.start,
    required this.cover,
    this.length = 1,
    this.stack,
    this.stackSize = 1,
    this.leads = false,
  });

  /// Index in the source list of the first item under this cell.
  final int start;

  /// Number of items under this cell: more than one for a folded stack.
  final int length;

  /// Index in the source list of the item shown.
  final int cover;

  /// Key of the stack this cell belongs to, folded or unfolded, or `null`
  /// for an item outside any stack.
  final String? stack;

  /// Number of items in the stack, or 1 outside a stack.
  final int stackSize;

  /// Whether this cell folds or unfolds its stack: the folded stack itself,
  /// or the cover of an unfolded one.
  final bool leads;

  /// Whether this cell stands for several items.
  bool get folded => length > 1;
}

/// Cells of [items], sorted newest first, with each run of consecutive
/// items of the same duplicate group taken on the same day folded into one
/// cell, unless its key is in [unfolded].
///
/// [stackOf] gives the key of an item's group by item id; [coverOf] the id
/// of the item to show for a key (the group's best pick). A run without
/// that item shows its first. Runs never cross midnight, so a stack stays
/// in its date section.
List<TimelineCell> buildCells(
  List<MediaItem> items, {
  Map<String, String> stackOf = const {},
  Map<String, String> coverOf = const {},
  Set<String> unfolded = const {},
}) {
  final cells = <TimelineCell>[];
  var i = 0;
  while (i < items.length) {
    final key = stackOf[items[i].id];
    var end = i + 1;
    if (key != null) {
      final day = _bucket(items[i].takenAt.toLocal(), TimelineGrouping.day);
      while (end < items.length &&
          stackOf[items[end].id] == key &&
          _bucket(items[end].takenAt.toLocal(), TimelineGrouping.day) == day) {
        end++;
      }
    }
    final size = end - i;
    if (key == null || size < 2) {
      cells.add(TimelineCell(start: i, cover: i));
      i = end;
      continue;
    }
    var cover = i;
    for (var j = i; j < end; j++) {
      if (items[j].id == coverOf[key]) cover = j;
    }
    if (unfolded.contains(key)) {
      for (var j = i; j < end; j++) {
        cells.add(
          TimelineCell(
            start: j,
            cover: j,
            stack: key,
            stackSize: size,
            leads: j == cover,
          ),
        );
      }
    } else {
      cells.add(
        TimelineCell(
          start: i,
          length: size,
          cover: cover,
          stack: key,
          stackSize: size,
          leads: true,
        ),
      );
    }
    i = end;
  }
  return cells;
}
