import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cleanup_lists.g.dart';

/// The cleanup lists opened from the Stats tab. Each is a timeline of its
/// own selection, with selection and batch move to the trash. See
/// `docs/features/cleanup.md`.
enum CleanupList {
  /// Screenshots older than the age chosen in Settings.
  screenshots,

  /// Videos larger than the size chosen in Settings, largest first.
  largeVideos,
}

/// Bytes in a megabyte, as `formatBytes` shows sizes.
const int _megabyte = 1024 * 1024;

/// Screenshots taken before the day [ageDays] before [today].
MediaSelection oldScreenshots({
  required int ageDays,
  required DateTime today,
}) => MediaSelection(
  filter: MediaFilter.screenshots,
  takenBefore: DateTime(today.year, today.month, today.day - ageDays),
);

/// Videos of at least [megabytes], largest first.
MediaSelection largeVideos({required int megabytes}) => MediaSelection(
  filter: MediaFilter.largeVideos,
  minSizeBytes: megabytes * _megabyte,
  sort: const MediaSort(field: MediaSortField.size),
);

/// Selection shown by [list], with the thresholds chosen in Settings.
///
/// Screenshot ages count in whole days, so the selection stays the same
/// all day and lists keyed by it are not reloaded.
@riverpod
MediaSelection cleanupSelection(Ref ref, CleanupList list) {
  final settings = ref.watch(appSettingsControllerProvider);
  return switch (list) {
    CleanupList.screenshots => oldScreenshots(
      ageDays: settings.screenshotAgeDays,
      today: DateTime.now(),
    ),
    CleanupList.largeVideos => largeVideos(
      megabytes: settings.largeVideoMegabytes,
    ),
  };
}
