import 'package:clean_gallery/analysis/similarity.dart';
import 'package:clean_gallery/core/database/settings_repository.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/ritual.dart';
import 'package:clean_gallery/domain/slideshow.dart';
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

  /// Sets whether timelines use the corrected capture date.
  Future<void> setCorrectedDates({required bool value}) async {
    state = state.copyWith(correctedDates: value);
    await _repository.writeBool(SettingKeys.correctedDates, value: value);
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

  /// Records that the index follows the index rules [version].
  Future<void> setIndexRules(int version) async {
    state = state.copyWith(indexRules: version);
    await _repository.write(SettingKeys.indexRules, '$version');
  }

  /// Sets the age from which screenshots are offered for cleaning.
  Future<void> setScreenshotAgeDays(int days) async {
    state = state.copyWith(screenshotAgeDays: days);
    await _repository.write(SettingKeys.screenshotAgeDays, '$days');
  }

  /// Sets the size from which videos are offered for cleaning.
  Future<void> setLargeVideoMegabytes(int megabytes) async {
    state = state.copyWith(largeVideoMegabytes: megabytes);
    await _repository.write(SettingKeys.largeVideoMegabytes, '$megabytes');
  }

  /// Limits duplicates and similar photos to [period] (capture dates), or
  /// to none with `null`. The duplicate scan runs again.
  Future<void> setDuplicatePeriod(DateFilter? period) async {
    final empty =
        period == null || (period.start == null && period.end == null);
    final value = empty ? null : period;
    state = state.copyWith(duplicatePeriod: value);
    final end = value?.end;
    await _repository.write(
      SettingKeys.duplicatePeriodStart,
      value?.start == null ? '' : isoDay(value!.start!),
    );
    await _repository.write(
      SettingKeys.duplicatePeriodEnd,
      // Stored as the last day, included.
      end == null ? '' : isoDay(end.subtract(const Duration(hours: 12))),
    );
  }

  /// Sets the similar photo sensitivity. Choosing
  /// [SimilaritySensitivity.custom] starts from the thresholds in use.
  Future<void> setSimilaritySensitivity(
    SimilaritySensitivity sensitivity,
  ) async {
    if (sensitivity == SimilaritySensitivity.custom &&
        state.similaritySensitivity != SimilaritySensitivity.custom) {
      await setCustomThresholds(state.similarityThresholds);
    }
    state = state.copyWith(similaritySensitivity: sensitivity);
    await _repository.write(
      SettingKeys.similaritySensitivity,
      sensitivity.name,
    );
  }

  /// Sets the thresholds of the advanced mode, clamped to the offered
  /// ranges.
  Future<void> setCustomThresholds(SimilarityThresholds thresholds) async {
    final value = SimilarityThresholds(
      strict: thresholds.strict.clamp(0, SimilarityThresholds.maxStrict),
      loose: thresholds.loose.clamp(0, SimilarityThresholds.maxLoose),
      window: Duration(
        seconds: thresholds.window.inSeconds.clamp(
          0,
          SimilarityThresholds.maxWindow.inSeconds,
        ),
      ),
    );
    state = state.copyWith(customThresholds: value);
    await _repository.write(SettingKeys.similarityStrict, '${value.strict}');
    await _repository.write(SettingKeys.similarityLoose, '${value.loose}');
    await _repository.write(
      SettingKeys.similarityWindow,
      '${value.window.inSeconds}',
    );
  }

  /// Remembers [options] as the defaults of the next slideshow.
  Future<void> setSlideshowOptions(SlideshowOptions options) async {
    state = state.copyWith(slideshowOptions: options);
    await _repository.write(SettingKeys.slideshowOptions, options.encode());
  }

  /// Sets how often memories are offered.
  Future<void> setMemories(MemoriesFrequency frequency) async {
    state = state.copyWith(memories: frequency);
    await _repository.write(SettingKeys.memories, frequency.name);
  }

  /// Sets the day and time of the memories notification: [time]'s day is
  /// a day of the week or of the month after its repeat.
  Future<void> setMemoriesTime(RecurringTime time) async {
    final valid = time.valid;
    state = valid.repeat == Repeat.weekly
        ? state.copyWith(
            memoriesWeekday: valid.day,
            memoriesMinute: valid.minute,
          )
        : state.copyWith(
            memoriesMonthDay: valid.day,
            memoriesMinute: valid.minute,
          );
    await _repository.write(
      valid.repeat == Repeat.weekly
          ? SettingKeys.memoriesWeekday
          : SettingKeys.memoriesMonthDay,
      '${valid.day}',
    );
    await _repository.write(SettingKeys.memoriesMinute, '${valid.minute}');
  }

  /// Sets whether a notification says when memories are ready.
  Future<void> setMemoriesNotify({required bool value}) async {
    state = state.copyWith(memoriesNotify: value);
    await _repository.writeBool(SettingKeys.memoriesNotify, value: value);
  }
}
