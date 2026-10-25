import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/settings_repository.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:drift/drift.dart' hide isNull;
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
  );

  test('schema version is 1', () {
    expect(db.schemaVersion, 1);
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
