import 'package:freezed_annotation/freezed_annotation.dart';

part 'ritual.freezed.dart';

/// How often a ritual (or the memories notification) comes back. Stored by
/// name in the database.
enum Repeat {
  /// Every week, on a day of the week.
  weekly,

  /// Every month, on a day of the month.
  monthly,
}

/// When something recurring happens: every week or month, on [day], at
/// [minute] past midnight, local time.
@freezed
abstract class RecurringTime with _$RecurringTime {
  /// Creates a time.
  const factory RecurringTime({
    /// Weekly or monthly.
    required Repeat repeat,

    /// Day of the week (`DateTime.monday` 1 to `DateTime.sunday` 7) when
    /// weekly, day of the month (1 to [maxDayOfMonth]) when monthly.
    required int day,

    /// Minutes past midnight, 0 to 1439.
    required int minute,
  }) = _RecurringTime;

  const RecurringTime._();

  /// Last day of the month offered: every month has it.
  static const maxDayOfMonth = 28;

  /// This time with [day] and [minute] brought into their ranges.
  RecurringTime get valid => copyWith(
    day: day.clamp(1, repeat == Repeat.weekly ? 7 : maxDayOfMonth),
    minute: minute.clamp(0, 24 * 60 - 1),
  );
}

/// What a ritual plays. Stored by name in the database.
enum RitualContent {
  /// Photos and videos of the last seven days.
  lastWeek,

  /// Photos and videos of the previous calendar month.
  lastMonth,

  /// A saved slideshow ([Ritual.targetId]).
  savedSlideshow,

  /// A user album ([Ritual.targetId]).
  userAlbum,
}

/// A recurring slideshow scheduled by the user, e.g. "every Sunday at
/// 7 pm: the week's photos".
///
/// At that time, a notification says the slideshow is ready; the app
/// builds it only when the notification is tapped. Nothing runs in the
/// background (ADR 0027).
@freezed
abstract class Ritual with _$Ritual {
  /// Creates a ritual.
  const factory Ritual({
    /// Database identifier.
    required int id,

    /// What it plays.
    required RitualContent content,

    /// When it comes back.
    required RecurringTime time,

    /// Id of the saved slideshow or user album, for those contents.
    int? targetId,

    /// Whether its notifications are scheduled.
    @Default(true) bool enabled,
  }) = _Ritual;
}
