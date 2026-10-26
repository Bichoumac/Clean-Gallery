import 'package:clean_gallery/domain/timeline.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Video length as `m:ss`, or `h:mm:ss` from one hour.
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
}

/// Section header text: "Today", "Yesterday", a full date, or a month.
///
/// [now] is injectable for tests.
String formatSectionDate(
  BuildContext context,
  DateTime date,
  TimelineGrouping grouping, {
  DateTime? now,
}) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final today = now ?? DateTime.now();
  if (grouping == TimelineGrouping.month) {
    final pattern = date.year == today.year
        ? _format('MMMM', locale, DateFormat.MMMM)
        : _format('yMMMM', locale, DateFormat.yMMMM);
    return _capitalize(pattern.format(date));
  }
  final todayStart = DateTime(today.year, today.month, today.day);
  final days = todayStart.difference(date).inDays;
  if (days == 0) return l10n.timelineToday;
  if (days == 1) return l10n.timelineYesterday;
  final pattern = date.year == today.year
      ? _format('MMMMEEEEd', locale, DateFormat.MMMMEEEEd)
      : _format('yMMMMEEEEd', locale, DateFormat.yMMMMEEEEd);
  return _capitalize(pattern.format(date));
}

/// File size with a unit and one decimal: "812 KB", "4.2 MB", "1.3 GB" in
/// English; "812 Ko", "4,2 Mo" in French.
String formatBytes(BuildContext context, int bytes) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final number = NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: 1,
  );
  const kilo = 1024;
  if (bytes < kilo) return l10n.sizeBytes('$bytes');
  if (bytes < kilo * kilo) {
    return l10n.sizeKilobytes('${(bytes / kilo).round()}');
  }
  if (bytes < kilo * kilo * kilo) {
    return l10n.sizeMegabytes(number.format(bytes / (kilo * kilo)));
  }
  return l10n.sizeGigabytes(number.format(bytes / (kilo * kilo * kilo)));
}

/// Month and year, capitalized: "March 2024", "Mars 2024".
String formatMonth(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return _capitalize(
    _format('yMMMM', locale, DateFormat.yMMMM).format(date.toLocal()),
  );
}

/// Date and time of a media item, for the viewer and screen readers.
String formatMediaDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return _format(
    'yMMMd Hm',
    locale,
    (locale) => DateFormat.yMMMd(locale).add_Hm(),
  ).format(date.toLocal());
}

/// Date formats by pattern and locale. Building a [DateFormat] parses its
/// pattern and locale data; every thumbnail formats a date for its screen
/// reader label, so formats are built once and reused.
final _formats = <String, DateFormat>{};

DateFormat _format(
  String pattern,
  String locale,
  DateFormat Function(String locale) create,
) => _formats.putIfAbsent('$pattern|$locale', () => create(locale));

/// French month and day names are lowercase; titles start with a capital.
String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
