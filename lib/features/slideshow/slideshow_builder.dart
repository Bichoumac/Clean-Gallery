import 'dart:math';

import 'package:clean_gallery/analysis/schedule.dart';
import 'package:clean_gallery/core/database/media_index_repository.dart';
import 'package:clean_gallery/core/database/memory_repository.dart';
import 'package:clean_gallery/core/database/slideshow_repository.dart';
import 'package:clean_gallery/core/database/trash_repository.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/memory.dart';
import 'package:clean_gallery/domain/ritual.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:flutter/foundation.dart';

/// What a slideshow plays, as given to the player (`AppRoutes.slideshow`).
@immutable
sealed class SlideshowSource {
  const SlideshowSource();
}

/// The items of a selection: an album page (with its date range), a
/// period, a search.
final class SelectionSlideshow extends SlideshowSource {
  /// Creates the source; [title] is proposed when saving.
  const SelectionSlideshow(this.selection, {required this.title});

  /// Items to play.
  final MediaSelection selection;

  /// Name of the album or period.
  final String title;
}

/// Items picked in a timeline.
final class PickedSlideshow extends SlideshowSource {
  /// Creates the source; [title] is proposed when saving.
  const PickedSlideshow(this.ids, {required this.title});

  /// Ids of the picked items.
  final List<String> ids;

  /// Name of the timeline they were picked in.
  final String title;
}

/// A saved slideshow, played as it was saved.
final class SavedSlideshowSource extends SlideshowSource {
  /// Creates the source.
  const SavedSlideshowSource(this.id);

  /// Its database id.
  final int id;
}

/// An automatic memory.
final class MemorySlideshow extends SlideshowSource {
  /// Creates the source.
  const MemorySlideshow(this.memory);

  /// The memory.
  final Memory memory;
}

/// A ritual, opened from its notification.
final class RitualSlideshow extends SlideshowSource {
  /// Creates the source.
  const RitualSlideshow(this.ritualId);

  /// Its database id.
  final int ritualId;
}

/// A slideshow ready to play: its items in order and its options.
@immutable
final class BuiltSlideshow {
  /// Creates a built slideshow.
  const BuiltSlideshow({
    required this.items,
    required this.options,
    this.title,
    this.savedId,
  });

  /// Items in playing order.
  final List<MediaItem> items;

  /// Options it plays with.
  final SlideshowOptions options;

  /// Title of a saved slideshow, or of the source when it has one.
  final String? title;

  /// Id of the saved slideshow it plays, so *Save* is not offered again.
  final int? savedId;
}

/// Builds slideshows: reads the items of a [SlideshowSource] from the
/// media index, leaves out trashed items, and, as the options ask, videos,
/// blurry photos and duplicates other than the best one.
///
/// Runs only while the app is open, when a slideshow is started; also
/// counts the good photos of memories ([goodItems]).
final class SlideshowBuilder {
  /// Creates a builder on the repositories.
  SlideshowBuilder({
    required this.index,
    required this.trash,
    required this.slideshows,
    required this.memories,
    Random? random,
  }) : _random = random ?? Random();

  /// The media index.
  final MediaIndexRepository index;

  /// The app trash.
  final TrashRepository trash;

  /// Saved slideshows.
  final SlideshowRepository slideshows;

  /// Memories and rituals.
  final MemoryRepository memories;

  final Random _random;

  /// Builds [source] with [options] (the user's defaults); a saved
  /// slideshow plays with its own. Returns no items when there is nothing
  /// left to play, e.g. a ritual whose album was deleted.
  Future<BuiltSlideshow> build(
    SlideshowSource source,
    SlideshowOptions options,
  ) async {
    switch (source) {
      case SelectionSlideshow(:final selection, :final title):
        return BuiltSlideshow(
          items: _ordered(await goodItems(selection, options), options),
          options: options,
          title: title,
        );
      case PickedSlideshow(:final ids, :final title):
        return BuiltSlideshow(
          items: _ordered(
            await goodItems(MediaSelection(ids: ids), options),
            options,
          ),
          options: options,
          title: title,
        );
      case SavedSlideshowSource(:final id):
        return await _saved(id);
      case MemorySlideshow(:final memory):
        // A memory is made of its good photos, whatever the options say.
        final good = options.copyWith(skipDuplicatesAndBlurry: true);
        return BuiltSlideshow(
          items: _ordered(await goodItems(memory.selection, good), good),
          options: good,
        );
      case RitualSlideshow(:final ritualId):
        final ritual = await memories.ritual(ritualId);
        if (ritual == null) {
          return BuiltSlideshow(items: const [], options: options);
        }
        return switch (ritual.content) {
          RitualContent.savedSlideshow => await _saved(ritual.targetId ?? -1),
          RitualContent.userAlbum => BuiltSlideshow(
            items: _ordered(
              await goodItems(
                MediaSelection(userAlbumId: ritual.targetId ?? -1),
                options,
              ),
              options,
            ),
            options: options,
          ),
          RitualContent.lastWeek || RitualContent.lastMonth => BuiltSlideshow(
            items: _ordered(
              await goodItems(
                MediaSelection(
                  filter: MediaFilter.camera,
                  dates: ritualDates(ritual.content, DateTime.now()),
                ),
                options,
              ),
              options,
            ),
            options: options,
          ),
        };
    }
  }

  /// Items of [selection] that a slideshow with [options] plays, oldest
  /// first: trashed items left out, videos when not included, and blurry
  /// or dark photos and duplicates other than the best one when skipped.
  Future<List<MediaItem>> goodItems(
    MediaSelection selection,
    SlideshowOptions options,
  ) async {
    final skip = options.skipDuplicatesAndBlurry;
    final base = selection.copyWith(
      sort: const MediaSort(descending: false),
      goodOnly: selection.goodOnly || skip,
    );
    final trashed = await trash.trashedIds();
    var items = [
      for (final item in await index.load(base))
        if (!trashed.contains(item.id) &&
            (options.includeVideos || !item.isVideo))
          item,
    ];
    if (skip && items.length > 1) {
      final others = {
        for (final group in await index.duplicateGroups(base))
          for (final item in group.items.skip(1)) item.id,
      };
      items = [
        for (final item in items)
          if (!others.contains(item.id)) item,
      ];
    }
    return items;
  }

  /// A saved slideshow: its items in their saved order, leaving out those
  /// trashed or no longer on the device.
  Future<BuiltSlideshow> _saved(int id) async {
    final saved = await slideshows.find(id);
    if (saved == null) {
      return const BuiltSlideshow(items: [], options: SlideshowOptions());
    }
    final ids = await slideshows.itemIds(id);
    final trashed = await trash.trashedIds();
    final byId = {
      for (final item in await index.load(MediaSelection(ids: ids)))
        item.id: item,
    };
    return BuiltSlideshow(
      items: [
        for (final id in ids)
          if (byId[id] case final item? when !trashed.contains(id)) item,
      ],
      options: saved.options,
      title: saved.title,
      savedId: id,
    );
  }

  List<MediaItem> _ordered(List<MediaItem> items, SlideshowOptions options) =>
      options.order == SlideshowOrder.shuffled
      ? ([...items]..shuffle(_random))
      : items;
}
