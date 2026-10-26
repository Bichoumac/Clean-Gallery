import 'package:clean_gallery/domain/enums.dart';

/// A resolved capture date and where it was read from.
typedef CaptureDate = ({DateTime date, DateSource source});

/// Earliest year accepted from a file name; older digits are taken for a
/// counter or an id rather than a date.
const _minYear = 1990;

/// A date in a file name: `20240315`, `2024-03-15`, `2024_03_15` or
/// `2024.03.15`, optionally followed by a time `142233`, `14-22-33`,
/// `14.22.33` or `14:22:33` (milliseconds allowed after it). The date must
/// not touch other digits, so ids and counters are not read as dates.
final _fileNameDate = RegExp(
  r'(?<!\d)((?:19|20)\d{2})([-_.]?)(0[1-9]|1[0-2])\2(0[1-9]|[12]\d|3[01])'
  r'(?:[-_ T]?([01]\d|2[0-3])([-_.:]?)([0-5]\d)\6([0-5]\d)(?:\d{3})?)?'
  r'(?!\d)',
);

/// Capture date of an item, by order of reliability:
///
/// 1. [platformDate] when [fromMetadata]: the platform read it from the
///    file's metadata (EXIF `DateTimeOriginal`, video creation time).
/// 2. A date in [fileName], e.g. `IMG_20240315_142233.jpg` or
///    `IMG-20240315-WA0001.jpg`. A date without a time keeps
///    [platformDate]'s time when both are the same day, noon otherwise.
/// 3. [platformDate] otherwise: the date the file was added to the device.
///
/// Dates after [now] are ignored. See `docs/analysis-engine.md`.
CaptureDate resolveCaptureDate({
  required DateTime platformDate,
  required bool fromMetadata,
  String? fileName,
  DateTime? now,
}) {
  if (fromMetadata) return (date: platformDate, source: DateSource.exif);
  final named = fileName == null
      ? null
      : dateFromFileName(fileName, now: now, sameDayAs: platformDate);
  if (named != null) return (date: named, source: DateSource.filename);
  return (date: platformDate, source: DateSource.file);
}

/// The date written in [fileName], in local time, or `null` if there is
/// none or it is not plausible (before 1990 or after [now]).
///
/// When the name has a date but no time, the result is [sameDayAs] if it
/// falls on that day, otherwise noon.
DateTime? dateFromFileName(
  String fileName, {
  DateTime? now,
  DateTime? sameDayAs,
}) {
  final latest = now ?? DateTime.now();
  for (final match in _fileNameDate.allMatches(fileName)) {
    final year = int.parse(match[1]!);
    final month = int.parse(match[3]!);
    final day = int.parse(match[4]!);
    final day0 = DateTime(year, month, day);
    // DateTime rolls over invalid days (Feb 30 → Mar 2): reject those.
    if (day0.month != month || year < _minYear || day0.isAfter(latest)) {
      continue;
    }
    if (match[5] == null) {
      if (sameDayAs != null &&
          sameDayAs.year == year &&
          sameDayAs.month == month &&
          sameDayAs.day == day) {
        return sameDayAs;
      }
      return DateTime(year, month, day, 12);
    }
    final date = DateTime(
      year,
      month,
      day,
      int.parse(match[5]!),
      int.parse(match[7]!),
      int.parse(match[8]!),
    );
    if (!date.isAfter(latest)) return date;
  }
  return null;
}
