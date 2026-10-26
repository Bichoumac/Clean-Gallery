import 'package:clean_gallery/domain/album.dart';
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
  }) = _AppSettings;

  /// Smallest and largest trash retention, in days.
  static const minRetentionDays = 1;

  /// See [minRetentionDays].
  static const maxRetentionDays = 90;
}

/// Key identifying a timeline (a tab or an album) in
/// [AppSettings.viewSorts]. The date filter is not part of it: it is kept
/// for the session only.
String viewKey(MediaSelection base) =>
    '${base.filter.name}:${base.albumId ?? ''}';

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
