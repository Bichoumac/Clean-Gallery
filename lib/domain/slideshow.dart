import 'dart:convert';

import 'package:clean_gallery/domain/media_item.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'slideshow.freezed.dart';

/// How one photo of a slideshow gives way to the next.
enum SlideshowTransition {
  /// The next photo fades in over the current one.
  crossfade,

  /// Crossfade, and each photo slowly zooms in ("Ken Burns" effect).
  kenBurns,
}

/// Order of the items of a slideshow.
enum SlideshowOrder {
  /// Oldest first, as they were taken.
  byDate,

  /// Shuffled once when the slideshow is built.
  shuffled,
}

/// Music played during a slideshow.
@freezed
sealed class SlideshowMusic with _$SlideshowMusic {
  /// No music.
  const factory SlideshowMusic.none() = NoMusic;

  /// A free track bundled with the app, by [BundledTrack.id].
  const factory SlideshowMusic.bundled(String trackId) = BundledMusic;

  /// A track from the phone, picked with the system file picker: its
  /// document [uri] (the app keeps read access to that file only) and the
  /// [name] shown to the user.
  const factory SlideshowMusic.device({
    required String uri,
    required String name,
  }) = DeviceMusic;

  const SlideshowMusic._();

  /// Music from [json], or none when it is not valid.
  factory SlideshowMusic.parse(Object? json) {
    if (json is! Map) return const SlideshowMusic.none();
    return switch (json['type']) {
      'bundled' when json['id'] is String => SlideshowMusic.bundled(
        json['id']! as String,
      ),
      'device' when json['uri'] is String => SlideshowMusic.device(
        uri: json['uri']! as String,
        name: json['name'] is String ? json['name']! as String : '',
      ),
      _ => const SlideshowMusic.none(),
    };
  }

  /// This music as a JSON-compatible map.
  Map<String, Object?> toJson() => switch (this) {
    NoMusic() => {'type': 'none'},
    BundledMusic(:final trackId) => {'type': 'bundled', 'id': trackId},
    DeviceMusic(:final uri, :final name) => {
      'type': 'device',
      'uri': uri,
      'name': name,
    },
  };
}

/// A free track bundled with the app (`assets/music/`), credited in About.
@immutable
final class BundledTrack {
  /// Creates a track.
  const BundledTrack({
    required this.id,
    required this.title,
    required this.asset,
    required this.credit,
  });

  /// Stable identifier, stored in [SlideshowMusic.bundled].
  final String id;

  /// Title shown in the music choices.
  final String title;

  /// Asset path, e.g. `assets/music/calm.mp3`.
  final String asset;

  /// Author and license, shown in About.
  final String credit;
}

/// Free tracks bundled with the app. Empty until tracks whose license allows
/// redistribution in an app with ads (CC0 preferred) are chosen by the
/// product owner; the options then offer them (see
/// `docs/features/slideshow.md#music`).
const bundledTracks = <BundledTrack>[];

/// Options of a slideshow, chosen in the sheet shown before it starts and
/// remembered as the defaults of the next one.
@freezed
abstract class SlideshowOptions with _$SlideshowOptions {
  /// Creates options; the defaults are those of a fresh install.
  const factory SlideshowOptions({
    /// Seconds each photo stays on screen, one of [photoSecondsChoices].
    @Default(5) int photoSeconds,

    /// Transition between items.
    @Default(SlideshowTransition.kenBurns) SlideshowTransition transition,

    /// Order of the items.
    @Default(SlideshowOrder.byDate) SlideshowOrder order,

    /// Whether videos are played (muted, [maxVideoSeconds] at most).
    @Default(true) bool includeVideos,

    /// Whether blurry photos, and duplicates other than the best one, are
    /// left out.
    @Default(true) bool skipDuplicatesAndBlurry,

    /// Music played during the slideshow.
    @Default(SlideshowMusic.none()) SlideshowMusic music,
  }) = _SlideshowOptions;

  const SlideshowOptions._();

  /// Options from [text] written by [encode]; missing or invalid values
  /// take their default, and anything unreadable gives the defaults.
  factory SlideshowOptions.decode(String? text) {
    const defaults = SlideshowOptions();
    if (text == null) return defaults;
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return defaults;
    }
    if (json is! Map) return defaults;
    T byName<T extends Enum>(List<T> all, Object? name, T fallback) =>
        all.where((e) => e.name == name).firstOrNull ?? fallback;
    final seconds = json['seconds'];
    return SlideshowOptions(
      photoSeconds: photoSecondsChoices.contains(seconds)
          ? seconds! as int
          : defaults.photoSeconds,
      transition: byName(
        SlideshowTransition.values,
        json['transition'],
        defaults.transition,
      ),
      order: byName(SlideshowOrder.values, json['order'], defaults.order),
      includeVideos: json['videos'] is bool
          ? json['videos']! as bool
          : defaults.includeVideos,
      skipDuplicatesAndBlurry: json['skip'] is bool
          ? json['skip']! as bool
          : defaults.skipDuplicatesAndBlurry,
      music: SlideshowMusic.parse(json['music']),
    );
  }

  /// Durations per photo offered, in seconds.
  static const photoSecondsChoices = [3, 5, 8];

  /// Longest time a video plays before the next item, in seconds.
  static const maxVideoSeconds = 10;

  /// These options as JSON text, as stored in the settings and in saved
  /// slideshows.
  String encode() => jsonEncode({
    'seconds': photoSeconds,
    'transition': transition.name,
    'order': order.name,
    'videos': includeVideos,
    'skip': skipDuplicatesAndBlurry,
    'music': music.toJson(),
  });
}

/// A slideshow saved by the user (*Save*), listed in *My slideshows*.
///
/// Stored in the database with its items in order and its options: it
/// plays again at any time, without any video file (ADR 0026).
@freezed
abstract class SavedSlideshow with _$SavedSlideshow {
  /// Creates a saved slideshow.
  const factory SavedSlideshow({
    /// Database identifier.
    required int id,

    /// Title chosen by the user (or proposed when saving).
    required String title,

    /// Options it plays with.
    required SlideshowOptions options,

    /// Number of its items still shown (trashed or deleted ones left out).
    required int count,

    /// When it was saved; the list shows the newest first.
    required DateTime createdAt,

    /// Its first item still shown, used as the cover; `null` when none is
    /// left.
    MediaItem? cover,
  }) = _SavedSlideshow;
}
