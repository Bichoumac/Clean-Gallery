import 'dart:async';

import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/geo.dart';
import 'package:clean_gallery/domain/gray_image.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/media_metadata.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:clean_gallery/platform/ads_service.dart';
import 'package:clean_gallery/platform/media_source.dart';
import 'package:clean_gallery/platform/music_player.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:clean_gallery/platform/platform_bridge.dart';
import 'package:clean_gallery/platform/purchase_service.dart';
import 'package:clean_gallery/platform/reminder_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image/image.dart' as img;

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
    return locationGranted = true;
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

  /// Edited photos saved, as `(photo id, width, height)`.
  final savedEdits = <(String, int, int)>[];

  /// Called by [saveEditedPhoto] to make the new photo (e.g. add it to a
  /// [FakeMediaSource]); returns its id. Defaults to `'saved'`.
  String Function(MediaItem photo)? onSaveEdit;

  @override
  Future<String> saveEditedPhoto(
    MediaItem photo, {
    required int width,
    required int height,
    required Uint8List rgba,
  }) async {
    assert(rgba.length == width * height * 4, 'one RGBA pixel each');
    savedEdits.add((photo.id, width, height));
    return onSaveEdit?.call(photo) ?? 'saved';
  }

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

  /// Locations passed to [openMap].
  final mapRequests = <(double, double)>[];

  @override
  Future<bool> openMap(double latitude, double longitude) async {
    mapRequests.add((latitude, longitude));
    return true;
  }

  /// Whether the screen is kept on.
  bool keepScreenOn = false;

  @override
  Future<void> setKeepScreenOn({required bool on}) async => keepScreenOn = on;

  /// The window's own brightness, or `null` when it follows the system.
  double? brightness;

  /// Brightness reported while the window follows the system.
  double systemBrightness = 0.5;

  /// Media volume, from 0 to 1.
  double volume = 0.5;

  @override
  Future<double> screenBrightness() async => brightness ?? systemBrightness;

  @override
  Future<void> setScreenBrightness(double? value) async => brightness = value;

  @override
  Future<double> mediaVolume() async => volume;

  @override
  Future<void> setMediaVolume(double value) async => volume = value;
}

/// [MusicPlayer] that records what it is asked to play.
class FakeLoadedAd implements LoadedAd {
  bool disposed = false;

  @override
  Widget get view => const SizedBox.expand(key: ValueKey('fake-ad'));

  @override
  void dispose() => disposed = true;
}

/// Ads off by default, as in a build without ad unit IDs.
class FakeAdsService implements AdsService {
  FakeAdsService({
    this.configured = false,
    this.consent = true,
    this.privacyRequired = false,
    this.fill = true,
  });

  @override
  final bool configured;

  bool consent;
  bool privacyRequired;
  bool fill;

  /// Calls in order, to check that nothing loads before consent.
  final calls = <String>[];

  @override
  Future<bool> gatherConsent() async {
    calls.add('consent');
    return consent;
  }

  @override
  Future<void> initialize() async => calls.add('initialize');

  @override
  Future<bool> privacyOptionsRequired() async => privacyRequired;

  @override
  Future<bool> showPrivacyOptions() async {
    calls.add('privacy');
    return consent;
  }

  @override
  Future<LoadedAd?> loadBanner() async {
    calls.add('banner');
    return fill ? FakeLoadedAd() : null;
  }

  @override
  Future<LoadedAd?> loadNative(NativeAdColors colors) async {
    calls.add('native');
    return fill ? FakeLoadedAd() : null;
  }

  @override
  Future<void> preloadInterstitial() async => calls.add('preload');

  @override
  Future<void> showInterstitial() async => calls.add('interstitial');
}

class FakePurchaseService implements PurchaseService {
  FakePurchaseService({this.owned = false, this.price = '4,99 €'});

  /// The store's answer; `null` when it cannot be reached.
  bool? owned;
  String? price;
  bool canOpen = true;
  int buys = 0;

  final _updates = StreamController<PurchaseUpdate>.broadcast();

  void emit(PurchaseUpdate update) => _updates.add(update);

  @override
  Stream<PurchaseUpdate> get updates => _updates.stream;

  @override
  Future<String?> removeAdsPrice() async => price;

  @override
  Future<bool?> ownsRemoveAds() async => owned;

  @override
  Future<bool> buyRemoveAds() async {
    buys++;
    return canOpen;
  }

  @override
  Future<void> dispose() => _updates.close();
}

class FakeMusicPlayer implements MusicPlayer {
  /// Music playing, or `null`.
  SlideshowMusic? playing;

  /// Whether the track is paused.
  bool paused = false;

  /// Last volume set.
  double volume = 1;

  /// Whether [play] succeeds; `false` acts as a deleted file.
  bool playable = true;

  /// Track returned by [pick]; `null` acts as a cancelled picker.
  DeviceMusic? picked;

  /// Tracks given back with [release].
  final released = <String>[];

  @override
  Future<bool> play(SlideshowMusic music, {double volume = 1}) async {
    if (music is NoMusic || !playable) return false;
    playing = music;
    paused = false;
    this.volume = volume;
    return true;
  }

  @override
  Future<void> pause() async => paused = true;

  @override
  Future<void> resume() async => paused = false;

  @override
  Future<void> setVolume(double volume) async => this.volume = volume;

  @override
  Future<void> stop() async => playing = null;

  @override
  Future<DeviceMusic?> pick() async => picked;

  @override
  Future<void> release(String uri) async => released.add(uri);
}

/// [ReminderService] that keeps the scheduled reminders.
class FakeReminderService implements ReminderService {
  /// Reminders of the last [schedule] call.
  List<Reminder> scheduled = const [];

  /// Whether notifications are allowed.
  bool allowed = false;

  /// Whether [requestPermission] grants them.
  bool grant = true;

  /// Number of permission requests.
  int requests = 0;

  /// Payload returned once by [takeLaunchPayload].
  String? launchPayload;

  /// Feeds [taps].
  final tapController = StreamController<String>.broadcast();

  @override
  Future<void> schedule(List<Reminder> reminders) async =>
      scheduled = reminders;

  @override
  Future<bool> canNotify() async => allowed;

  @override
  Future<bool> requestPermission() async {
    requests++;
    if (grant) allowed = true;
    return allowed;
  }

  @override
  Future<String?> takeLaunchPayload() async {
    final payload = launchPayload;
    launchPayload = null;
    return payload;
  }

  @override
  Stream<String> get taps => tapController.stream;
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
///
/// Items listed in [folderItems] belong to that folder, named after the
/// matching entry of [folders]; other items belong to no folder.
class FakeMediaSource implements MediaSource {
  /// Creates a source with [items] and the given [folders].
  FakeMediaSource({
    this.items = const [],
    this.folders = const [],
    this.folderItems = const {},
    this.version = '1',
  });

  /// Every item of the library, newest first.
  List<MediaItem> items;

  /// Folders the items of [folderItems] belong to; only `id` and `name`
  /// are used.
  List<Album> folders;

  /// Items of each folder, by folder id.
  Map<String, List<MediaItem>> folderItems;

  /// Version reported by [snapshot].
  String version;

  /// Revision of items by id; items not listed have revision 1.
  final revisions = <String, int>{};

  /// Ids of items whose date is not from their metadata, so the index
  /// resolves it from the file name.
  final withoutMetadataDate = <String>{};

  /// Ids passed to [describe], per call.
  final describeCalls = <List<String>>[];

  /// Number of [snapshot] calls.
  int snapshots = 0;

  @override
  Future<LibrarySnapshot> snapshot() async {
    snapshots++;
    return LibrarySnapshot(
      version: version,
      revisions: {for (final item in items) item.id: revisions[item.id] ?? 1},
    );
  }

  @override
  Future<List<IndexedMedia>> describe(List<String> ids) async {
    describeCalls.add(ids);
    final wanted = ids.toSet();
    return [
      for (final item in items)
        if (wanted.contains(item.id)) _indexed(item),
    ];
  }

  /// Content fingerprint of items by id; items not listed hash to their
  /// own id, so they are all different.
  final hashes = <String, String>{};

  /// Ids passed to [contentHashes], per call.
  final hashCalls = <List<String>>[];

  @override
  Future<Map<String, String>> contentHashes(List<MediaItem> items) async {
    hashCalls.add([for (final item in items) item.id]);
    return {for (final item in items) item.id: hashes[item.id] ?? item.id};
  }

  /// Grayscale thumbnail of photos by id; photos not listed have none.
  final grayImages = <String, GrayImage>{};

  /// Ids passed to [grayThumbnails], per call.
  final grayCalls = <List<String>>[];

  /// Photos whose batch fails with a platform error in [grayThumbnails].
  final grayFailures = <String>{};

  @override
  Future<Map<String, GrayImage>> grayThumbnails(
    List<MediaItem> photos, {
    required int side,
  }) async {
    grayCalls.add([for (final photo in photos) photo.id]);
    if (photos.any((photo) => grayFailures.contains(photo.id))) {
      throw PlatformException(code: 'failed');
    }
    return {for (final photo in photos) photo.id: ?grayImages[photo.id]};
  }

  /// Metadata of items by id; items not listed have none.
  final metadatas = <String, MediaMetadata>{};

  @override
  Future<MediaMetadata> metadata(MediaItem item) async =>
      metadatas[item.id] ?? MediaMetadata.empty;

  /// Location of items by id, as read by [locations]; others have none.
  final positions = <String, GeoPoint>{};

  /// Ids passed to [locations], per call.
  final locationCalls = <List<String>>[];

  @override
  Future<Map<String, GeoPoint>> locations(List<MediaItem> items) async {
    locationCalls.add([for (final item in items) item.id]);
    return {for (final item in items) item.id: ?positions[item.id]};
  }

  IndexedMedia _indexed(MediaItem item) {
    final folder = folders.where(
      (f) => folderItems[f.id]?.any((i) => i.id == item.id) ?? false,
    );
    return IndexedMedia(
      item: item,
      albumId: folder.firstOrNull?.id,
      albumName: folder.firstOrNull?.name ?? '',
      revision: revisions[item.id] ?? 1,
      hasMetadataDate: !withoutMetadataDate.contains(item.id),
    );
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

/// Map tiles that are all blank, so tests never reach the network.
class BlankTileProvider extends TileProvider {
  /// A transparent 1 × 1 PNG.
  static final _blank = MemoryImage(
    img.encodePng(img.Image(width: 1, height: 1, numChannels: 4)),
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _blank;
}
