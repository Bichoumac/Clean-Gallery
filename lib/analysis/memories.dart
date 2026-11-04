import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/memory.dart';

/// Fewest good photos for a "This week, N years ago" memory.
///
/// Fewer photos make a slideshow of a few seconds; a week of a usual
/// camera roll easily has eight. Adjustable once tried on real libraries.
const minWeekPhotos = 8;

/// Fewest good photos for an "On this day" memory: a day with this many
/// photos was usually an event (a birthday, an outing).
const minDayPhotos = 6;

/// The week (Monday to Sunday) holding [day], as a capture-date range.
DateFilter weekOf(DateTime day) {
  final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1));
  return DateFilter.days(
    monday,
    DateTime(monday.year, monday.month, monday.day + 6),
  );
}

/// [day] moved [years] years back; February 29 becomes March 1 in other
/// years, as [DateTime] normalizes it.
DateTime yearsBefore(DateTime day, int years) =>
    DateTime(day.year - years, day.month, day.day);

/// Periods a memory can come from on [today]: for each year from 1 back to
/// [oldest] (the oldest capture date of the library), the week of today's
/// date that year, and that very day.
///
/// The week is the one holding the same date [yearsBefore], so "this week,
/// 1 year ago" on Wednesday 4 November 2026 is Monday 3 to Sunday
/// 9 November 2025.
List<MemoryPeriod> memoryPeriods(DateTime today, {required DateTime oldest}) {
  final periods = <MemoryPeriod>[];
  for (var years = 1; ; years++) {
    final day = yearsBefore(today, years);
    final week = weekOf(day);
    // Nothing that old in the library.
    if (!week.end!.isAfter(oldest)) break;
    periods
      ..add(
        MemoryPeriod(kind: MemoryKind.thisWeek, yearsAgo: years, dates: week),
      )
      ..add(
        MemoryPeriod(
          kind: MemoryKind.onThisDay,
          yearsAgo: years,
          dates: DateFilter.days(day, day),
        ),
      );
  }
  return periods;
}

/// A period that may become a memory, see [memoryPeriods].
final class MemoryPeriod {
  /// Creates a period.
  const MemoryPeriod({
    required this.kind,
    required this.yearsAgo,
    required this.dates,
  });

  /// Day or week.
  final MemoryKind kind;

  /// How many years ago.
  final int yearsAgo;

  /// The capture-date range.
  final DateFilter dates;

  /// Key of the memory this period would make, see [Memory.keyOf].
  String get key => Memory.keyOf(kind, dates.start!);

  /// Fewest good photos for a memory of this kind.
  int get minPhotos =>
      kind == MemoryKind.onThisDay ? minDayPhotos : minWeekPhotos;
}

/// The memories among [periods], given the number of good photos of each
/// ([goodPhotos], by [MemoryPeriod.key]; missing means none), most recent
/// year first.
///
/// One memory per year at most: the day when it has [minDayPhotos], since
/// it is the more striking one, otherwise the week when it has
/// [minWeekPhotos]; neither when both are short.
List<Memory> pickMemories(
  List<MemoryPeriod> periods,
  Map<String, int> goodPhotos,
) {
  final byYear = <int, Memory>{};
  for (final period in periods) {
    final count = goodPhotos[period.key] ?? 0;
    if (count < period.minPhotos) continue;
    final memory = Memory(
      key: period.key,
      kind: period.kind,
      yearsAgo: period.yearsAgo,
      dates: period.dates,
      count: count,
    );
    final current = byYear[period.yearsAgo];
    if (current == null || period.kind == MemoryKind.onThisDay) {
      byYear[period.yearsAgo] = memory;
    }
  }
  final years = byYear.keys.toList()..sort();
  return [for (final year in years) byYear[year]!];
}
