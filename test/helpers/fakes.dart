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

/// A photo (or video, with [duration]) taken at [takenAt], id `'$id'`.
MediaItem testItem(
  int id, {
  DateTime? takenAt,
  Duration? duration,
  bool isFavorite = false,
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
    fileName: 'IMG_$id.jpg',
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

  List<MediaItem> _select(MediaSelection selection) {
    final albumId = selection.albumId;
    if (albumId != null) return folderItems[albumId] ?? const [];
    return switch (selection.filter) {
      MediaFilter.all => items,
      MediaFilter.photos => items.where((i) => !i.isVideo).toList(),
      MediaFilter.videos => items.where((i) => i.isVideo).toList(),
      MediaFilter.favorites => items.where((i) => i.isFavorite).toList(),
    };
  }

  @override
  Future<List<Album>> albums() async => folders;

  @override
  Future<int> count(MediaSelection selection) async =>
      _select(selection).length;

  @override
  Future<List<MediaItem>> load(
    MediaSelection selection, {
    required int start,
    required int end,
  }) async {
    loads.add((start, end));
    final all = _select(selection);
    return all.sublist(start.clamp(0, all.length), end.clamp(0, all.length));
  }

  @override
  ImageProvider thumbnail(MediaItem item, {required int size}) =>
      MemoryImage(kTransparentPng);

  @override
  ImageProvider fullImage(MediaItem item, {int maxDimension = 4096}) =>
      MemoryImage(kTransparentPng);

  @override
  Future<Uri?> videoUri(MediaItem item) async => null;
}
