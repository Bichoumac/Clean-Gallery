import 'dart:async';

import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/geo.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_scan.g.dart';

/// Items whose location is read per call to the media source: only file
/// headers are read, about a tenth of a second for 20 photos.
const locationBatchSize = 20;

/// Reads the location of new items from their files, for the map.
///
/// Incremental and resumable like the duplicate scan: each item is read
/// once (`assets.location_read`) and read again only when its file changes.
/// Runs only with the media location permission, which the platform needs
/// to reveal GPS data; items stay unread without it, so granting it later
/// reads them all. State: incremented each time locations are saved, so
/// the map refreshes while the scan runs.
@Riverpod(keepAlive: true)
class LocationScan extends _$LocationScan {
  Future<void>? _running;
  bool _again = false;

  @override
  int build() => 0;

  /// Reads the locations still unread. A call made while a scan runs
  /// schedules one more pass; platform errors stop the scan, and what was
  /// read so far is kept.
  Future<void> run() {
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = _runLoop();
  }

  Future<void> _runLoop() async {
    try {
      do {
        _again = false;
        await _runOnce();
      } while (_again && ref.mounted);
    } on PlatformException {
      // Permission withdrawn or platform failure: the next scan resumes.
    } finally {
      _running = null;
    }
  }

  Future<void> _runOnce() async {
    final permissions = ref.read(permissionServiceProvider);
    if (await permissions.mediaAccess() == MediaAccess.denied) return;
    if (!await permissions.hasLocationAccess() || !ref.mounted) return;
    final repository = ref.read(mediaIndexRepositoryProvider);
    final source = ref.read(mediaSourceProvider);
    while (ref.mounted) {
      final batch = await repository.locationCandidates(
        limit: locationBatchSize,
      );
      if (batch.isEmpty || !ref.mounted) return;
      final locations = await source.locations(batch);
      if (!ref.mounted) return;
      await repository.saveLocations(batch, locations);
      if (ref.mounted && locations.isNotEmpty) state++;
    }
  }
}

/// Every item with a known location, trashed ones left out, newest first.
@riverpod
Future<List<LocatedItem>> locatedMedia(Ref ref) {
  ref
    ..watch(trashedIdsProvider)
    ..watch(mediaIndexProvider.select((s) => s.revision))
    ..watch(locationScanProvider);
  return ref.watch(mediaIndexRepositoryProvider).located();
}
