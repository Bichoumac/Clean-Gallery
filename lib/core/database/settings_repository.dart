import 'package:clean_gallery/core/database/app_database.dart';

/// Keys of the `settings` table. Add new keys here, never inline strings.
abstract final class SettingKeys {
  /// Whether the first-launch onboarding has been completed.
  static const onboardingCompleted = 'onboarding_completed';
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
}
