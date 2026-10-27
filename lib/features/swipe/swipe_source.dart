import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/features/cleanup/cleanup_lists.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'swipe_source.g.dart';

/// Kinds of [SwipeSource].
enum SwipeSourceKind {
  /// Every photo.
  allPhotos,

  /// Blurry or very dark photos.
  blurry,

  /// Old screenshots.
  screenshots,

  /// The photos and videos of one month.
  month,

  /// The photos and videos of one device folder.
  folder,
}

/// What a swipe session goes through. Each source has one session, which
/// resumes where the user left it; its [key] identifies it in
/// `swipe_history` and in the route.
@immutable
final class SwipeSource {
  /// Every photo.
  const SwipeSource.allPhotos() : this._(SwipeSourceKind.allPhotos);

  /// Blurry or very dark photos.
  const SwipeSource.blurry() : this._(SwipeSourceKind.blurry);

  /// Old screenshots, by the age set in Settings.
  const SwipeSource.screenshots() : this._(SwipeSourceKind.screenshots);

  /// The items of [month] (its first day).
  SwipeSource.month(DateTime month)
    : this._(SwipeSourceKind.month, month: DateTime(month.year, month.month));

  /// The items of the folder [albumId].
  const SwipeSource.folder(String albumId)
    : this._(SwipeSourceKind.folder, albumId: albumId);

  const SwipeSource._(this.kind, {this.month, this.albumId});

  /// Kind of source.
  final SwipeSourceKind kind;

  /// First day of the month, for [SwipeSourceKind.month].
  final DateTime? month;

  /// Folder id, for [SwipeSourceKind.folder].
  final String? albumId;

  /// Stable text form: `all`, `blurry`, `screenshots`, `month:2024-03`,
  /// `folder:<id>`.
  String get key => switch (kind) {
    SwipeSourceKind.allPhotos => 'all',
    SwipeSourceKind.blurry => 'blurry',
    SwipeSourceKind.screenshots => 'screenshots',
    SwipeSourceKind.month =>
      'month:${month!.year.toString().padLeft(4, '0')}-'
          '${month!.month.toString().padLeft(2, '0')}',
    SwipeSourceKind.folder => 'folder:$albumId',
  };

  /// The source of [key], or `null` when it is not a valid key.
  static SwipeSource? parse(String key) {
    switch (key) {
      case 'all':
        return const SwipeSource.allPhotos();
      case 'blurry':
        return const SwipeSource.blurry();
      case 'screenshots':
        return const SwipeSource.screenshots();
    }
    if (key.startsWith('folder:') && key.length > 'folder:'.length) {
      return SwipeSource.folder(key.substring('folder:'.length));
    }
    final month = RegExp(r'^month:(\d{4})-(\d{2})$').firstMatch(key);
    if (month != null) {
      final number = int.parse(month[2]!);
      if (number < 1 || number > 12) return null;
      return SwipeSource.month(DateTime(int.parse(month[1]!), number));
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is SwipeSource && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'SwipeSource($key)';
}

/// Oldest first: the product owner's choice for swipe sessions.
const swipeOrder = MediaSort(descending: false);

/// Items of [source], oldest first.
@riverpod
MediaSelection swipeSelection(Ref ref, SwipeSource source) =>
    switch (source.kind) {
      SwipeSourceKind.allPhotos => MediaSelection.photos,
      SwipeSourceKind.blurry => ref.watch(
        cleanupSelectionProvider(CleanupList.poorQuality),
      ),
      SwipeSourceKind.screenshots => ref.watch(
        cleanupSelectionProvider(CleanupList.screenshots),
      ),
      SwipeSourceKind.month => MediaSelection(
        dates: DateFilter(
          start: source.month,
          end: DateTime(source.month!.year, source.month!.month + 1),
        ),
      ),
      SwipeSourceKind.folder => MediaSelection(albumId: source.albumId),
    }.copyWith(sort: swipeOrder);

/// Months with items, newest first, for the source list.
@riverpod
Future<List<({DateTime month, int count})>> swipeMonths(Ref ref) {
  ref
    ..watch(trashedIdsProvider)
    ..watch(mediaIndexProvider.select((s) => s.revision))
    ..watch(appSettingsControllerProvider.select((s) => s.correctedDates));
  return ref.watch(mediaIndexRepositoryProvider).months();
}

/// Number of decisions taken in each session, by [SwipeSource.key].
@riverpod
Future<Map<String, int>> swipeProgress(Ref ref) =>
    ref.watch(swipeRepositoryProvider).progress();
