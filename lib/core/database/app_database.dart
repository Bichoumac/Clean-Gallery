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
  int get schemaVersion => 1;

  /// Migration steps, applied in order from the installed version.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Add one `if (from < n)` block per schema version, in order.
      // Example for version 2:
      //   if (from < 2) { await m.addColumn(assets, assets.someColumn); }
    },
    beforeOpen: (details) async {
      // Foreign keys are off by default in SQLite; enable them per connection.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
