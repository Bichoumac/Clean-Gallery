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
        ? DateFormat.MMMM(locale)
        : DateFormat.yMMMM(locale);
    return _capitalize(pattern.format(date));
  }
  final todayStart = DateTime(today.year, today.month, today.day);
  final days = todayStart.difference(date).inDays;
  if (days == 0) return l10n.timelineToday;
  if (days == 1) return l10n.timelineYesterday;
  final pattern = date.year == today.year
      ? DateFormat.MMMMEEEEd(locale)
      : DateFormat.yMMMMEEEEd(locale);
  return _capitalize(pattern.format(date));
}

/// Date and time of a media item, for the viewer and screen readers.
String formatMediaDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMd(locale).add_Hm().format(date.toLocal());
}

/// French month and day names are lowercase; titles start with a capital.
String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
