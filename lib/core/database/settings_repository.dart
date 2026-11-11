import 'package:clean_gallery/analysis/similarity.dart';
import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/slideshow.dart';

/// Keys of the `settings` table. Add new keys here, never inline strings.
abstract final class SettingKeys {
  /// Whether the first-launch onboarding has been completed.
  static const onboardingCompleted = 'onboarding_completed';

  /// [AppSettings.trashRetentionDays].
  static const trashRetentionDays = 'trash_retention_days';

  /// [AppSettings.removeGpsOnShare].
  static const removeGpsOnShare = 'remove_gps_on_share';

  /// [AppSettings.defaultColumns].
  static const defaultColumns = 'default_columns';

  /// [AppSettings.theme], by enum name.
  static const theme = 'theme';

  /// [AppSettings.language], by enum name.
  static const language = 'language';

  /// [AppSettings.lastPurgeCheck], as an ISO 8601 date.
  static const lastPurgeCheck = 'last_purge_check';

  /// [AppSettings.correctedDates].
  static const correctedDates = 'corrected_dates';

  /// [AppSettings.indexRules].
  static const indexRules = 'index_rules';

  /// [AppSettings.mediaIndexVersion].
  static const mediaIndexVersion = 'media_index_version';

  /// [AppSettings.similaritySensitivity], by name.
  static const similaritySensitivity = 'similarity_sensitivity';

  /// Strict pHash distance of [AppSettings.customThresholds].
  static const similarityStrict = 'similarity_strict';

  /// Loose pHash distance of [AppSettings.customThresholds].
  static const similarityLoose = 'similarity_loose';

  /// Time window of [AppSettings.customThresholds], in seconds.
  static const similarityWindow = 'similarity_window';

  /// Prefix of one [AppSettings.viewSorts] entry: `view_sort:<viewKey>`.
  static const viewSortPrefix = 'view_sort:';

  /// First day of [AppSettings.duplicatePeriod], as an ISO 8601 date, or
  /// empty for none.
  static const duplicatePeriodStart = 'duplicate_period_start';

  /// Last day of [AppSettings.duplicatePeriod] (included), as an ISO 8601
  /// date, or empty for none.
  static const duplicatePeriodEnd = 'duplicate_period_end';

  /// [AppSettings.screenshotAgeDays].
  static const screenshotAgeDays = 'screenshot_age_days';

  /// [AppSettings.largeVideoMegabytes].
  static const largeVideoMegabytes = 'large_video_megabytes';

  /// [AppSettings.slideshowOptions], as `SlideshowOptions.encode` writes
  /// them.
  static const slideshowOptions = 'slideshow_options';

  /// [AppSettings.memories], by name.
  static const memories = 'memories';

  /// [AppSettings.memoriesWeekday].
  static const memoriesWeekday = 'memories_weekday';

  /// [AppSettings.memoriesMonthDay].
  static const memoriesMonthDay = 'memories_month_day';

  /// [AppSettings.memoriesMinute].
  static const memoriesMinute = 'memories_minute';

  /// [AppSettings.memoriesNotify].
  static const memoriesNotify = 'memories_notify';
}

/// Reads and writes application settings in the `settings` table.
///
/// Values are stored as text; typed helpers convert booleans and integers.
final class SettingsRepository {
  /// Creates a repository backed by [_db].
  const SettingsRepository(this._db);

  final AppDatabase _db;

  /// Returns the stored value for [key], or `null` when unset.
  Future<String?> read(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Stores [value] under [key], replacing any previous value.
  Future<void> write(String key, String value) {
    return _db
        .into(_db.settings)
        .insertOnConflictUpdate(SettingRow(key: key, value: value));
  }

  /// Returns the boolean stored under [key], or [defaultValue] when unset.
  Future<bool> readBool(String key, {bool defaultValue = false}) async {
    final value = await read(key);
    if (value == null) return defaultValue;
    return value == 'true';
  }

  /// Stores [value] under [key] as `true` or `false`.
  Future<void> writeBool(String key, {required bool value}) {
    return write(key, value.toString());
  }

  /// All user settings, with defaults for unset or invalid values.
  Future<AppSettings> loadAppSettings() async {
    final rows = await _db.select(_db.settings).get();
    final values = {for (final row in rows) row.key: row.value};
    const defaults = AppSettings();

    int intIn(String key, int fallback, int min, int max) {
      final parsed = int.tryParse(values[key] ?? '');
      return parsed == null || parsed < min || parsed > max ? fallback : parsed;
    }

    T byName<T extends Enum>(List<T> all, String key, T fallback) =>
        all.where((e) => e.name == values[key]).firstOrNull ?? fallback;

    return AppSettings(
      trashRetentionDays: intIn(
        SettingKeys.trashRetentionDays,
        defaults.trashRetentionDays,
        AppSettings.minRetentionDays,
        AppSettings.maxRetentionDays,
      ),
      removeGpsOnShare: switch (values[SettingKeys.removeGpsOnShare]) {
        'true' => true,
        'false' => false,
        _ => defaults.removeGpsOnShare,
      },
      defaultColumns: intIn(
        SettingKeys.defaultColumns,
        defaults.defaultColumns,
        2,
        6,
      ),
      theme: byName(ThemePreference.values, SettingKeys.theme, defaults.theme),
      language: byName(
        LanguagePreference.values,
        SettingKeys.language,
        defaults.language,
      ),
      viewSorts: <String, MediaSort>{
        for (final MapEntry(:key, :value) in values.entries)
          if (key.startsWith(SettingKeys.viewSortPrefix))
            key.substring(SettingKeys.viewSortPrefix.length): ?decodeSort(
              value,
            ),
      },
      lastPurgeCheck: DateTime.tryParse(
        values[SettingKeys.lastPurgeCheck] ?? '',
      ),
      correctedDates: values[SettingKeys.correctedDates] != 'false',
      mediaIndexVersion: values[SettingKeys.mediaIndexVersion],
      indexRules: int.tryParse(values[SettingKeys.indexRules] ?? ''),
      similaritySensitivity: byName(
        SimilaritySensitivity.values,
        SettingKeys.similaritySensitivity,
        defaults.similaritySensitivity,
      ),
      customThresholds: SimilarityThresholds(
        strict: intIn(
          SettingKeys.similarityStrict,
          defaults.customThresholds.strict,
          0,
          SimilarityThresholds.maxStrict,
        ),
        loose: intIn(
          SettingKeys.similarityLoose,
          defaults.customThresholds.loose,
          0,
          SimilarityThresholds.maxLoose,
        ),
        window: Duration(
          seconds: intIn(
            SettingKeys.similarityWindow,
            defaults.customThresholds.window.inSeconds,
            0,
            SimilarityThresholds.maxWindow.inSeconds,
          ),
        ),
      ),
      duplicatePeriod: decodePeriod(
        values[SettingKeys.duplicatePeriodStart],
        values[SettingKeys.duplicatePeriodEnd],
      ),
      screenshotAgeDays: intIn(
        SettingKeys.screenshotAgeDays,
        defaults.screenshotAgeDays,
        1,
        3650,
      ),
      largeVideoMegabytes: intIn(
        SettingKeys.largeVideoMegabytes,
        defaults.largeVideoMegabytes,
        1,
        100000,
      ),
      slideshowOptions: SlideshowOptions.decode(
        values[SettingKeys.slideshowOptions],
      ),
      memories: byName(
        MemoriesFrequency.values,
        SettingKeys.memories,
        defaults.memories,
      ),
      memoriesWeekday: intIn(
        SettingKeys.memoriesWeekday,
        defaults.memoriesWeekday,
        DateTime.monday,
        DateTime.sunday,
      ),
      memoriesMonthDay: intIn(
        SettingKeys.memoriesMonthDay,
        defaults.memoriesMonthDay,
        1,
        28,
      ),
      memoriesMinute: intIn(
        SettingKeys.memoriesMinute,
        defaults.memoriesMinute,
        0,
        24 * 60 - 1,
      ),
      memoriesNotify: values[SettingKeys.memoriesNotify] == 'true',
    );
  }
}

/// The duplicate period stored as its first and last days ([start] and
/// [end], ISO 8601 dates, either missing or empty), or `null` when neither
/// is set or they are in the wrong order.
DateFilter? decodePeriod(String? start, String? end) {
  DateTime? day(String? value) {
    final date = DateTime.tryParse(value ?? '');
    return date == null ? null : DateTime(date.year, date.month, date.day);
  }

  final first = day(start);
  final last = day(end);
  if (first == null && last == null) return null;
  if (first != null && last != null && last.isBefore(first)) return null;
  return DateFilter(
    start: first,
    end: last == null ? null : DateTime(last.year, last.month, last.day + 1),
  );
}

/// [date] as the ISO 8601 day `yyyy-mm-dd`.
String isoDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
