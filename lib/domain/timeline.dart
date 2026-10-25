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

/// Grouping used for a grid with [columns] columns: days while thumbnails
/// are large, months once the grid is dense.
TimelineGrouping groupingForColumns(int columns) =>
    columns <= 4 ? TimelineGrouping.day : TimelineGrouping.month;

DateTime _bucket(DateTime local, TimelineGrouping grouping) =>
    switch (grouping) {
      TimelineGrouping.day => DateTime(local.year, local.month, local.day),
      TimelineGrouping.month => DateTime(local.year, local.month),
    };
