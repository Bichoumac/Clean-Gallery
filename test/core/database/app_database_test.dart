import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/settings_repository.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = inMemoryDatabase());
  tearDown(() => db.close());

  AssetsCompanion asset(int id) => AssetsCompanion.insert(
    id: Value(id),
    folder: 'Camera',
    relativePath: 'DCIM/Camera/',
    fileName: 'IMG_$id.jpg',
    mimeType: 'image/jpeg',
    kind: MediaKind.photo,
    sizeBytes: 1000,
    width: 4000,
    height: 3000,
    modifiedAt: DateTime(2026),
    takenAt: DateTime(2026),
  );

  test('schema version is 3', () {
    expect(db.schemaVersion, 3);
  });

  test('stores enums by name', () async {
    await db
        .into(db.assets)
        .insert(
          asset(1).copyWith(captureSource: const Value(DateSource.filename)),
        );
    final row = await db.select(db.assets).getSingle();
    expect(row.kind, MediaKind.photo);
    expect(row.captureSource, DateSource.filename);
    expect(row.analysisVersion, 0);
  });

  test('foreign keys are enforced', () async {
    // Trash entry for an asset that does not exist.
    final insert = db
        .into(db.trashEntries)
        .insert(
          TrashEntriesCompanion.insert(
            assetId: const Value(42),
            trashedAt: DateTime(2026),
            expiresAt: DateTime(2026, 2),
            originalFolder: 'Camera',
          ),
        );
    await expectLater(insert, throwsA(isA<Exception>()));
  });

  test('deleting an asset cascades to its trash entry', () async {
    await db.into(db.assets).insert(asset(1));
    await db
        .into(db.trashEntries)
        .insert(
          TrashEntriesCompanion.insert(
            assetId: const Value(1),
            trashedAt: DateTime(2026),
            expiresAt: DateTime(2026, 2),
            originalFolder: 'Camera',
          ),
        );
    await db.delete(db.assets).go();
    expect(await db.select(db.trashEntries).get(), isEmpty);
  });

  test('migration 1 → 3 keeps trashed items and moves their date', () async {
    final old = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          // The two version 1 tables the migration touches, as Drift
          // created them, with one trashed item.
          raw
            ..execute(
              'CREATE TABLE "assets" ("id" INTEGER NOT NULL, '
              '"folder" TEXT NOT NULL, "relative_path" TEXT NOT NULL, '
              '"file_name" TEXT NOT NULL, "mime_type" TEXT NOT NULL, '
              '"kind" TEXT NOT NULL, "size_bytes" INTEGER NOT NULL, '
              '"width" INTEGER NOT NULL, "height" INTEGER NOT NULL, '
              '"duration_ms" INTEGER NULL, "modified_at" INTEGER NOT NULL, '
              '"capture_at" INTEGER NULL, "capture_source" TEXT NULL, '
              '"content_hash" TEXT NULL, "d_hash" INTEGER NULL, '
              '"p_hash" INTEGER NULL, "blur_score" REAL NULL, '
              '"burst_id" TEXT NULL, '
              '"is_screenshot" INTEGER NOT NULL DEFAULT 0, '
              '"is_favorite" INTEGER NOT NULL DEFAULT 0, '
              '"latitude" REAL NULL, "longitude" REAL NULL, '
              '"camera_model" TEXT NULL, '
              '"analysis_version" INTEGER NOT NULL DEFAULT 0, '
              'PRIMARY KEY ("id"))',
            )
            ..execute(
              'CREATE TABLE "trash_entries" ("asset_id" INTEGER NOT NULL '
              'REFERENCES assets (id) ON DELETE CASCADE, '
              '"trashed_at" INTEGER NOT NULL, "expires_at" INTEGER NOT NULL, '
              '"original_folder" TEXT NOT NULL, PRIMARY KEY ("asset_id"))',
            )
            ..execute(
              'INSERT INTO assets (id, folder, relative_path, file_name, '
              'mime_type, kind, size_bytes, width, height, modified_at, '
              "capture_at) VALUES (7, 'Camera', 'DCIM/Camera/', 'a.jpg', "
              "'image/jpeg', 'photo', 10, 4, 3, 100, 200)",
            )
            ..execute(
              'INSERT INTO trash_entries VALUES (7, 300, 400, '
              "'Camera')",
            )
            ..userVersion = 1;
        },
      ),
    );
    addTearDown(old.close);

    final row = await old.select(old.assets).getSingle();
    expect(row.takenAt, DateTime.fromMillisecondsSinceEpoch(200 * 1000));
    expect(row.captureAt, isNull);
    expect(row.bucketId, isNull);
    expect(row.mediaRevision, isNull);
    expect(await old.select(old.trashEntries).get(), hasLength(1));
    expect(row.brightness, isNull);
  });

  test('migration 2 → 3 adds the brightness, keeping the rows', () async {
    final old = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          // The version 2 assets table, as Drift created it.
          raw
            ..execute(
              'CREATE TABLE "assets" ("id" INTEGER NOT NULL, '
              '"folder" TEXT NOT NULL, "bucket_id" TEXT NULL, '
              '"relative_path" TEXT NOT NULL, '
              '"file_name" TEXT NOT NULL, "mime_type" TEXT NOT NULL, '
              '"kind" TEXT NOT NULL, "size_bytes" INTEGER NOT NULL, '
              '"width" INTEGER NOT NULL, "height" INTEGER NOT NULL, '
              '"duration_ms" INTEGER NULL, "modified_at" INTEGER NOT NULL, '
              '"taken_at" INTEGER NOT NULL, "media_revision" INTEGER NULL, '
              '"capture_at" INTEGER NULL, "capture_source" TEXT NULL, '
              '"content_hash" TEXT NULL, "d_hash" INTEGER NULL, '
              '"p_hash" INTEGER NULL, "blur_score" REAL NULL, '
              '"burst_id" TEXT NULL, '
              '"is_screenshot" INTEGER NOT NULL DEFAULT 0, '
              '"is_favorite" INTEGER NOT NULL DEFAULT 0, '
              '"latitude" REAL NULL, "longitude" REAL NULL, '
              '"camera_model" TEXT NULL, '
              '"analysis_version" INTEGER NOT NULL DEFAULT 0, '
              'PRIMARY KEY ("id"))',
            )
            ..execute(
              'INSERT INTO assets (id, folder, relative_path, file_name, '
              'mime_type, kind, size_bytes, width, height, modified_at, '
              "taken_at, p_hash, analysis_version) VALUES (7, 'Camera', "
              "'DCIM/Camera/', 'a.jpg', 'image/jpeg', 'photo', 10, 4, 3, "
              '100, 200, 42, 1)',
            )
            ..userVersion = 2;
        },
      ),
    );
    addTearDown(old.close);

    final row = await old.select(old.assets).getSingle();
    expect(row.pHash, 42);
    expect(row.analysisVersion, 1);
    expect(row.brightness, isNull);
  });

  group('SettingsRepository', () {
    late SettingsRepository settings;

    setUp(() => settings = SettingsRepository(db));

    test('returns null for an unset key', () async {
      expect(await settings.read('missing'), isNull);
    });

    test('overwrites an existing value', () async {
      await settings.write('k', 'a');
      await settings.write('k', 'b');
      expect(await settings.read('k'), 'b');
    });

    test('round-trips booleans with a default', () async {
      expect(await settings.readBool('flag'), isFalse);
      expect(await settings.readBool('flag', defaultValue: true), isTrue);
      await settings.writeBool('flag', value: true);
      expect(await settings.readBool('flag'), isTrue);
    });
  });
}
