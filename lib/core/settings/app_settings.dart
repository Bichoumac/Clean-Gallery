import 'package:clean_gallery/analysis/similarity.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/ritual.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';

/// Theme chosen in Settings.
enum ThemePreference {
  /// Follow the system's light or dark mode.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// Interface language chosen in Settings.
enum LanguagePreference {
  /// Follow the system language (English or French, English otherwise).
  system,

  /// English.
  english,

  /// French.
  french,
}

/// How often memories are offered, in Settings.
enum MemoriesFrequency {
  /// No memory card and no notification.
  off,

  /// Every week (the default): the notification, when turned on, comes
  /// on a day of the week.
  weekly,

  /// Every month, on a day of the month.
  monthly,
}

/// User settings, stored in the `settings` table and read before the first
/// frame. See `docs/features/settings.md`.
@freezed
abstract class AppSettings with _$AppSettings {
  /// Creates settings; defaults are the values of a fresh install.
  const factory AppSettings({
    /// Days an item stays in the app trash before it can be purged (1–90).
    @Default(30) int trashRetentionDays,

    /// Whether sharing removes GPS location by default.
    @Default(true) bool removeGpsOnShare,

    /// Column count of grids at launch (2–6).
    @Default(4) int defaultColumns,

    /// Light, dark or system theme.
    @Default(ThemePreference.system) ThemePreference theme,

    /// Interface language.
    @Default(LanguagePreference.system) LanguagePreference language,

    /// Whether timelines sort and group by the corrected capture date
    /// (photo metadata, then file name) instead of the platform's date.
    @Default(true) bool correctedDates,

    /// Sort order chosen for each timeline, by [viewKey].
    @Default(<String, MediaSort>{}) Map<String, MediaSort> viewSorts,

    /// Last day the expired trash was offered for purging, if any.
    DateTime? lastPurgeCheck,

    /// Platform media database version of the last complete index, or
    /// `null` before the first one. While `null`, empty lists show a
    /// loading state instead of an empty one.
    String? mediaIndexVersion,

    /// `indexRulesVersion` the index was built with (capture dates, burst
    /// ids), or `null` before the first index. An older value makes the
    /// next sync apply the rules to every item again.
    int? indexRules,

    /// How eager the similar photo search is.
    @Default(SimilaritySensitivity.medium)
    SimilaritySensitivity similaritySensitivity,

    /// Thresholds of the advanced mode, used when [similaritySensitivity]
    /// is [SimilaritySensitivity.custom].
    @Default(SimilarityThresholds.medium) SimilarityThresholds customThresholds,

    /// Capture dates duplicates and similar photos are looked for in, or
    /// `null` for the whole library (issue #19). Start and end are each
    /// optional; the end is exclusive (the day after the last day).
    DateFilter? duplicatePeriod,

    /// Age from which screenshots are offered for cleaning, in days.
    @Default(30) int screenshotAgeDays,

    /// Size from which videos are offered for cleaning, in megabytes.
    @Default(100) int largeVideoMegabytes,

    /// Options of the last slideshow, the defaults of the next one.
    @Default(SlideshowOptions()) SlideshowOptions slideshowOptions,

    /// How often memories are offered.
    @Default(MemoriesFrequency.weekly) MemoriesFrequency memories,

    /// Day of the week of the memories notification, when weekly.
    @Default(DateTime.sunday) int memoriesWeekday,

    /// Day of the month of the memories notification, when monthly.
    @Default(1) int memoriesMonthDay,

    /// Time of the memories notification, in minutes past midnight.
    @Default(19 * 60) int memoriesMinute,

    /// Whether a notification says when memories are ready. Off until the
    /// user turns it on, which asks for the notification permission.
    @Default(false) bool memoriesNotify,
  }) = _AppSettings;

  const AppSettings._();

  /// Thresholds the similar photo search uses.
  SimilarityThresholds get similarityThresholds =>
      similaritySensitivity == SimilaritySensitivity.custom
      ? customThresholds
      : SimilarityThresholds.of(similaritySensitivity);

  /// When the memories notification comes, or `null` when memories are
  /// off.
  RecurringTime? get memoriesTime => switch (memories) {
    MemoriesFrequency.off => null,
    MemoriesFrequency.weekly => RecurringTime(
      repeat: Repeat.weekly,
      day: memoriesWeekday,
      minute: memoriesMinute,
    ),
    MemoriesFrequency.monthly => RecurringTime(
      repeat: Repeat.monthly,
      day: memoriesMonthDay,
      minute: memoriesMinute,
    ),
  };

  /// Smallest and largest trash retention, in days.
  static const minRetentionDays = 1;

  /// See [minRetentionDays].
  static const maxRetentionDays = 90;

  /// Screenshot ages offered in Settings, in days.
  static const screenshotAgeChoices = [7, 30, 90, 365];

  /// Large video sizes offered in Settings, in megabytes.
  static const largeVideoChoices = [50, 100, 250, 500];
}

/// Key identifying a timeline (a tab or an album) in
/// [AppSettings.viewSorts]. The date filter is not part of it: it is kept
/// for the session only. Search results have their own keys, so sorting
/// them never sorts the tab searched in.
String viewKey(MediaSelection base) =>
    '${base.nameContains == null ? '' : 'search:'}'
    '${base.filter.name}:${base.albumId ?? ''}'
    '${base.userAlbumId == null ? '' : ':user${base.userAlbumId}'}';

/// [sort] as stored text, e.g. `size:desc`.
String encodeSort(MediaSort sort) =>
    '${sort.field.name}:${sort.descending ? 'desc' : 'asc'}';

/// Sort from stored text, or `null` when the text is not a valid sort.
MediaSort? decodeSort(String text) {
  final parts = text.split(':');
  if (parts.length != 2) return null;
  final field = MediaSortField.values.where((f) => f.name == parts[0]);
  if (field.isEmpty || (parts[1] != 'asc' && parts[1] != 'desc')) return null;
  return MediaSort(field: field.single, descending: parts[1] == 'desc');
}
