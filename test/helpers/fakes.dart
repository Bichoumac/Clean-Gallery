import 'dart:typed_data';

import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/platform/media_source.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:clean_gallery/platform/platform_bridge.dart';
import 'package:drift/native.dart';
import 'package:flutter/painting.dart';

/// Opens a fresh in-memory database for one test.
AppDatabase inMemoryDatabase() => AppDatabase(NativeDatabase.memory());

/// [PermissionService] that returns a fixed result and records calls.
class FakePermissionService implements PermissionService {
  /// Creates a fake whose requests return [result].
  FakePermissionService({this.result = MediaAccess.granted});

  /// Result returned by [requestMediaAccess] and [mediaAccess].
  MediaAccess result;

  /// Number of media access requests.
  int mediaRequests = 0;

  /// Number of location access requests.
  int locationRequests = 0;

  /// Number of times the app settings were opened.
  int settingsOpened = 0;

  @override
  Future<MediaAccess> mediaAccess() async => result;

  @override
  Future<MediaAccess> requestMediaAccess() async {
    mediaRequests++;
    return result;
  }

  /// Whether GPS metadata access is reported as granted.
  bool locationGranted = true;

  @override
  Future<bool> hasLocationAccess() async => locationGranted;

  @override
  Future<bool> requestLocationAccess() async {
    locationRequests++;
    return true;
  }

  @override
  Future<void> openAppSettings() async => settingsOpened++;
}

/// [PlatformBridge] that records calls instead of talking to Android.
class FakePlatformBridge implements PlatformBridge {
  /// Whether "Media management" is reported as granted.
  bool mediaManagementGranted = false;

  /// Number of times the "Media management" settings were opened.
  int mediaManagementOpened = 0;

  @override
  Future<bool> isMediaManagementGranted() async => mediaManagementGranted;

  @override
  Future<void> openMediaManagementSettings() async => mediaManagementOpened++;

  @override
  Future<int> sdkVersion() async => 34;

  /// Whether system requests (favorite, delete) are accepted by the user.
  bool acceptRequests = true;

  /// Favorite requests, as `(ids, favorite)`.
  final favoriteRequests = <(List<String>, bool)>[];

  /// Ids passed to [deletePermanently], per call.
  final deleteRequests = <List<String>>[];

  /// Share requests, as `(ids, removeLocation)`.
  final shareRequests = <(List<String>, bool)>[];

  @override
  Future<bool> setFavorite(
    List<MediaItem> items, {
    required bool favorite,
  }) async {
    favoriteRequests.add(([for (final i in items) i.id], favorite));
    return acceptRequests;
  }

  @override
  Future<bool> deletePermanently(List<MediaItem> items) async {
    deleteRequests.add([for (final i in items) i.id]);
    return acceptRequests;
  }

  @override
  Future<void> share(
    List<MediaItem> items, {
    required bool removeLocation,
  }) async {
    shareRequests.add(([for (final i in items) i.id], removeLocation));
  }
}

/// A 1 × 1 transparent PNG, used as every image of [FakeMediaSource].
final kTransparentPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
]);

/// A photo (or video, with [duration]) taken at [takenAt], id `'$id'`, in
/// the camera folder unless [relativePath] says otherwise.
MediaItem testItem(
  int id, {
  DateTime? takenAt,
  Duration? duration,
  bool isFavorite = false,
  int sizeBytes = 0,
  String relativePath = 'DCIM/Camera/',
}) {
  final at = takenAt ?? DateTime(2026, 10, 25, 12);
  return MediaItem(
    id: '$id',
    kind: duration == null ? MediaKind.photo : MediaKind.video,
    width: 4000,
    height: 3000,
    takenAt: at,
    modifiedAt: at,
    duration: duration ?? Duration.zero,
    isFavorite: isFavorite,
    sizeBytes: sizeBytes,
    fileName: 'IMG_$id.jpg',
    relativePath: relativePath,
  );
}

/// In-memory [MediaSource]. Items must be given newest first.
class FakeMediaSource implements MediaSource {
  /// Creates a source with [items] and the given [folders].
  FakeMediaSource({
    this.items = const [],
    this.folders = const [],
    this.folderItems = const {},
  });

  /// Every item of the library, newest first.
  List<MediaItem> items;

  /// Folders returned by [albums].
  List<Album> folders;

  /// Items of each folder, by folder id.
  Map<String, List<MediaItem>> folderItems;

  /// Ranges requested through [load], as `(start, end)`.
  final loads = <(int, int)>[];

  /// Selections passed to [load], in call order.
  final loadedSelections = <MediaSelection>[];

  /// Filters, date range and sort applied like `AndroidMediaSource` does.
  List<MediaItem> _select(
    MediaSelection selection, [
    Set<String> hidden = const {},
  ]) {
    final albumId = selection.albumId;
    final base = albumId != null ? folderItems[albumId] ?? const [] : items;
    final dates = selection.dates;
    final selected = base.where((i) {
      final kept = switch (selection.filter) {
        MediaFilter.all => true,
        MediaFilter.photos => !i.isVideo,
        MediaFilter.camera =>
          !i.isVideo && (i.relativePath ?? '').startsWith('DCIM/Camera/'),
        MediaFilter.videos => i.isVideo,
        MediaFilter.favorites => i.isFavorite,
      };
      return kept &&
          !hidden.contains(i.id) &&
          (dates == null || dates.contains(i.takenAt));
    }).toList();
    final sort = selection.sort;
    int compare(MediaItem a, MediaItem b) => switch (sort.field) {
      MediaSortField.date => a.takenAt.compareTo(b.takenAt),
      MediaSortField.name => (a.fileName ?? '').toLowerCase().compareTo(
        (b.fileName ?? '').toLowerCase(),
      ),
      MediaSortField.size => a.sizeBytes.compareTo(b.sizeBytes),
      MediaSortField.duration => a.duration.compareTo(b.duration),
    };
    // Ties keep the given order, like the SQL secondary sort keys.
    final position = {for (final (i, item) in base.indexed) item.id: i};
    return selected..sort((a, b) {
      final byField = sort.descending ? compare(b, a) : compare(a, b);
      return byField != 0
          ? byField
          : position[a.id]!.compareTo(position[b.id]!);
    });
  }

  @override
  Future<List<Album>> albums({Set<String> hidden = const {}}) async => folders;

  @override
  Future<int> count(
    MediaSelection selection, {
    Set<String> hidden = const {},
  }) async => _select(selection, hidden).length;

  @override
  Future<List<MediaItem>> load(
    MediaSelection selection, {
    required int start,
    required int end,
    Set<String> hidden = const {},
  }) async {
    loads.add((start, end));
    loadedSelections.add(selection);
    final all = _select(selection, hidden);
    return all.sublist(start.clamp(0, all.length), end.clamp(0, all.length));
  }

  @override
  ImageProvider thumbnail(MediaItem item, {required int size}) =>
      MemoryImage(kTransparentPng);

  @override
  ImageProvider preview(MediaItem item, {required int longestSide}) =>
      MemoryImage(kTransparentPng);

  @override
  ImageProvider fullImage(MediaItem item, {int maxDimension = 4096}) =>
      MemoryImage(kTransparentPng);

  @override
  Future<Uri?> videoUri(MediaItem item) async => null;
}
