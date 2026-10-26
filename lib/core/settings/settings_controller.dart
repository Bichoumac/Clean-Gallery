import 'package:clean_gallery/core/database/settings_repository.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_controller.g.dart';

/// Settings read in `main()` before the first frame, so the theme and
/// language are right from the start. Overridden there.
@Riverpod(keepAlive: true)
AppSettings initialAppSettings(Ref ref) => const AppSettings();

/// Current user settings. Each change is saved to the database at once.
@Riverpod(keepAlive: true)
class AppSettingsController extends _$AppSettingsController {
  @override
  AppSettings build() => ref.watch(initialAppSettingsProvider);

  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  /// Sets the trash retention, clamped to 1–90 days.
  Future<void> setTrashRetentionDays(int days) async {
    final value = days.clamp(
      AppSettings.minRetentionDays,
      AppSettings.maxRetentionDays,
    );
    state = state.copyWith(trashRetentionDays: value);
    await _repository.write(SettingKeys.trashRetentionDays, '$value');
  }

  /// Sets whether sharing removes GPS location by default.
  Future<void> setRemoveGpsOnShare({required bool value}) async {
    state = state.copyWith(removeGpsOnShare: value);
    await _repository.writeBool(SettingKeys.removeGpsOnShare, value: value);
  }

  /// Sets the column count of grids at launch, clamped to 2–6.
  Future<void> setDefaultColumns(int columns) async {
    final value = columns.clamp(2, 6);
    state = state.copyWith(defaultColumns: value);
    await _repository.write(SettingKeys.defaultColumns, '$value');
  }

  /// Sets the theme.
  Future<void> setTheme(ThemePreference theme) async {
    state = state.copyWith(theme: theme);
    await _repository.write(SettingKeys.theme, theme.name);
  }

  /// Sets the interface language.
  Future<void> setLanguage(LanguagePreference language) async {
    state = state.copyWith(language: language);
    await _repository.write(SettingKeys.language, language.name);
  }

  /// Remembers [sort] for the timeline of [base].
  Future<void> setViewSort(MediaSelection base, MediaSort sort) async {
    final key = viewKey(base);
    state = state.copyWith(viewSorts: {...state.viewSorts, key: sort});
    await _repository.write(
      '${SettingKeys.viewSortPrefix}$key',
      encodeSort(sort),
    );
  }

  /// Records that the expired trash was checked on [day].
  Future<void> setLastPurgeCheck(DateTime day) async {
    state = state.copyWith(lastPurgeCheck: day);
    await _repository.write(SettingKeys.lastPurgeCheck, day.toIso8601String());
  }

  /// Records that the media index is complete for the platform media
  /// database [version].
  Future<void> setMediaIndexVersion(String version) async {
    state = state.copyWith(mediaIndexVersion: version);
    await _repository.write(SettingKeys.mediaIndexVersion, version);
  }
}
