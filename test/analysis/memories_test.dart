import 'package:clean_gallery/analysis/memories.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/memory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A Wednesday.
  final today = DateTime(2026, 11, 4, 9, 30);

  test('a week runs from Monday to Sunday', () {
    expect(
      weekOf(DateTime(2025, 11, 4)),
      DateFilter(start: DateTime(2025, 11, 3), end: DateTime(2025, 11, 10)),
    );
    // Sunday belongs to the week that started on Monday.
    expect(weekOf(DateTime(2025, 11, 9)).start, DateTime(2025, 11, 3));
    // Across a month and a year.
    expect(
      weekOf(DateTime(2026)),
      DateFilter(start: DateTime(2025, 12, 29), end: DateTime(2026, 1, 5)),
    );
  });

  test('February 29 moves to March 1 in other years', () {
    expect(yearsBefore(DateTime(2028, 2, 29), 1), DateTime(2027, 3));
  });

  test('periods go back year by year to the oldest photo', () {
    final periods = memoryPeriods(today, oldest: DateTime(2024, 11, 5));
    expect(periods.map((p) => (p.kind, p.yearsAgo)), [
      (MemoryKind.thisWeek, 1),
      (MemoryKind.onThisDay, 1),
      (MemoryKind.thisWeek, 2),
      (MemoryKind.onThisDay, 2),
    ]);
    expect(
      periods[1].dates,
      DateFilter(start: DateTime(2025, 11, 4), end: DateTime(2025, 11, 5)),
    );
    expect(periods.first.key, 'thisWeek:2025-11-03');
  });

  test('no period without photos a year old', () {
    expect(memoryPeriods(today, oldest: DateTime(2026, 3)), isEmpty);
  });

  test('one memory per year: the day when it has enough photos', () {
    final periods = memoryPeriods(today, oldest: DateTime(2020));
    final memories = pickMemories(periods, {
      // 1 year ago: the day has enough, the week too.
      'thisWeek:2025-11-03': 30,
      'onThisDay:2025-11-04': minDayPhotos,
      // 2 years ago: only the week.
      'thisWeek:2024-11-04': minWeekPhotos,
      'onThisDay:2024-11-04': 3,
      // 3 years ago: too few.
      'thisWeek:2023-10-30': minWeekPhotos - 1,
    });
    expect(memories.map((m) => (m.kind, m.yearsAgo, m.count)), [
      (MemoryKind.onThisDay, 1, minDayPhotos),
      (MemoryKind.thisWeek, 2, minWeekPhotos),
    ]);
  });
}
