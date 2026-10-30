import 'package:clean_gallery/analysis/image_quality.dart';
import 'package:clean_gallery/core/database/tables.dart';
// Used by the generated part for enum-typed columns.
import 'package:clean_gallery/domain/enums.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// The application's local SQLite database.
///
/// Production uses [AppDatabase.open], which runs SQLite in a background
/// isolate so queries never block the UI. Tests pass an in-memory executor.
///
/// Schema changes **must** bump [schemaVersion] and add a step to
/// [migration]. See `docs/database.md` for the migration history.
@DriftDatabase(
  tables: [
    Assets,
    DuplicateGroups,
    DuplicateMembers,
    IgnoredPairs,
    TrashEntries,
    SwipeHistory,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates a database on top of the given query executor, `e` in Drift's
  /// generated base class.
  AppDatabase(super.e);

  /// Opens the on-device database file in a background isolate.
  factory AppDatabase.open() {
    return AppDatabase(
      driftDatabase(
        name: 'clean_gallery',
        native: const DriftNativeOptions(
          // Keep queries off the UI isolate.
          shareAcrossIsolates: true,
        ),
      ),
    );
  }

  /// Current schema version. Bump it for every schema change.
  @override
  int get schemaVersion => 5;

  /// Migration steps, applied in order from the installed version.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Add one `if (from < n)` block per schema version, in order.
      if (from < 2) {
        // Media index. Version 1 rows were only written by the trash, which
        // stored the MediaStore date in `capture_at`: move it to `taken_at`.
        // Foreign keys are still off here (`beforeOpen` runs after), so the
        // table can be rebuilt under the trash entries.
        await m.alterTable(
          TableMigration(
            assets,
            // The table is rebuilt with today's columns: list every column
            // added since version 1, later ones included.
            newColumns: [
              assets.bucketId,
              assets.takenAt,
              assets.mediaRevision,
              assets.brightness,
              assets.contrast,
              assets.locationRead,
            ],
            columnTransformer: {
              assets.takenAt: coalesce([assets.captureAt, assets.modifiedAt]),
              assets.captureAt: const Constant<DateTime>(null),
            },
          ),
        );
        await m.createIndex(assetsTakenAt);
        await m.createIndex(assetsBucketId);
      }
      // From version 1, the table rebuilt above already has the column.
      if (from == 2) {
        // Brightness of photos, measured with their sharpness (M5).
        await m.addColumn(assets, assets.brightness);
      }
      if (from >= 2 && from < 4) {
        // Contrast of photos, telling hazy photos from blurry ones (M6).
        await m.addColumn(assets, assets.contrast);
      }
      if (from >= 2 && from < 5) {
        // Whether the location was read, for the map (M7, built in M6).
        await m.addColumn(assets, assets.locationRead);
      }
      if (from == 3) {
        // Analysis version 3 only adds the contrast, and the contrast only
        // matters below the blur threshold: photos analysed by version 2
        // above it are up to date, the others are analysed again.
        await customStatement(
          'UPDATE assets SET analysis_version = 3 '
          'WHERE analysis_version = 2 '
          'AND (blur_score IS NULL OR blur_score >= $blurryBelow)',
        );
      }
    },
    beforeOpen: (details) async {
      // Foreign keys are off by default in SQLite; enable them per connection.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
