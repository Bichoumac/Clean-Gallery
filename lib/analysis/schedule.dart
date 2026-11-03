import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/ritual.dart';

/// The next [count] times of [time] strictly after [from], local time,
/// earliest first.
///
/// Computed with local [DateTime] fields, so a weekly ritual at 7 pm stays
/// at 7 pm across daylight saving changes.
List<DateTime> nextOccurrences(
  RecurringTime time, {
  required DateTime from,
  required int count,
}) {
  final valid = time.valid;
  final hour = valid.minute ~/ 60;
  final minute = valid.minute % 60;
  final occurrences = <DateTime>[];
  var candidate = switch (valid.repeat) {
    Repeat.weekly => DateTime(
      from.year,
      from.month,
      from.day + (valid.day - from.weekday) % 7,
      hour,
      minute,
    ),
    Repeat.monthly => DateTime(from.year, from.month, valid.day, hour, minute),
  };
  while (occurrences.length < count) {
    if (candidate.isAfter(from)) occurrences.add(candidate);
    candidate = switch (valid.repeat) {
      Repeat.weekly => DateTime(
        candidate.year,
        candidate.month,
        candidate.day + 7,
        hour,
        minute,
      ),
      Repeat.monthly => DateTime(
        candidate.year,
        candidate.month + 1,
        valid.day,
        hour,
        minute,
      ),
    };
  }
  return occurrences;
}

/// How many notifications of one recurring time are set in advance.
///
/// Every launch sets them again, so they only run out when the app is not
/// opened for that long: two months for a weekly one, half a year for a
/// monthly one.
int occurrencesAhead(Repeat repeat) => switch (repeat) {
  Repeat.weekly => 8,
  Repeat.monthly => 6,
};

/// Capture dates a ritual of [content] plays when opened at [now]: the
/// last seven days, today included, or the previous calendar month;
/// `null` for contents that are not a period.
DateFilter? ritualDates(RitualContent content, DateTime now) =>
    switch (content) {
      RitualContent.lastWeek => DateFilter.days(
        DateTime(now.year, now.month, now.day - 6),
        now,
      ),
      RitualContent.lastMonth => DateFilter(
        start: DateTime(now.year, now.month - 1),
        end: DateTime(now.year, now.month),
      ),
      RitualContent.savedSlideshow || RitualContent.userAlbum => null,
    };
