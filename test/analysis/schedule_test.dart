import 'package:clean_gallery/analysis/schedule.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/ritual.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Tuesday 3 November 2026, 10:00.
  final now = DateTime(2026, 11, 3, 10);

  test('weekly: the next Sundays at 7 pm', () {
    const time = RecurringTime(
      repeat: Repeat.weekly,
      day: DateTime.sunday,
      minute: 19 * 60,
    );
    expect(nextOccurrences(time, from: now, count: 3), [
      DateTime(2026, 11, 8, 19),
      DateTime(2026, 11, 15, 19),
      DateTime(2026, 11, 22, 19),
    ]);
  });

  test('weekly on today: today when the time is still ahead', () {
    const later = RecurringTime(
      repeat: Repeat.weekly,
      day: DateTime.tuesday,
      minute: 11 * 60,
    );
    expect(nextOccurrences(later, from: now, count: 1), [
      DateTime(2026, 11, 3, 11),
    ]);
    const earlier = RecurringTime(
      repeat: Repeat.weekly,
      day: DateTime.tuesday,
      minute: 10 * 60,
    );
    expect(nextOccurrences(earlier, from: now, count: 1), [
      DateTime(2026, 11, 10, 10),
    ]);
  });

  test('monthly: the first of the next months, across the year', () {
    const time = RecurringTime(repeat: Repeat.monthly, day: 1, minute: 9 * 60);
    expect(nextOccurrences(time, from: now, count: 3), [
      DateTime(2026, 12, 1, 9),
      DateTime(2027, 1, 1, 9),
      DateTime(2027, 2, 1, 9),
    ]);
  });

  test('out-of-range days and minutes are brought into range', () {
    const time = RecurringTime(repeat: Repeat.monthly, day: 31, minute: 5000);
    expect(nextOccurrences(time, from: now, count: 1), [
      DateTime(2026, 11, 28, 23, 59),
    ]);
  });

  test('ritual periods: the last seven days, the previous month', () {
    expect(
      ritualDates(RitualContent.lastWeek, now),
      DateFilter(start: DateTime(2026, 10, 28), end: DateTime(2026, 11, 4)),
    );
    expect(
      ritualDates(RitualContent.lastMonth, DateTime(2026, 1, 1, 8)),
      DateFilter(start: DateTime(2025, 12), end: DateTime(2026)),
    );
    expect(ritualDates(RitualContent.userAlbum, now), isNull);
  });
}
