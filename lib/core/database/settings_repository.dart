import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/domain/album.dart';

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

  /// Prefix of one [AppSettings.viewSorts] entry: `view_sort:<viewKey>`.
  static const viewSortPrefix = 'view_sort:';
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
    );
  }
}
