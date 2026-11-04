import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/memory.dart';
import 'package:clean_gallery/domain/ritual.dart';
import 'package:drift/drift.dart';

/// Automatic memories met so far, in the `memories` table, and the rituals,
/// in the `rituals` table.
///
/// Memories are found by `MemoryFinder` while the app is open; this class
/// only stores them so they stay in the *Memories* list until dismissed.
/// See `docs/features/memories.md`.
final class MemoryRepository {
  /// Creates the repository on [_db].
  const MemoryRepository(this._db);

  final AppDatabase _db;

  /// Stores the memories of [found] not met before; known ones, dismissed
  /// or not, are left as they are.
  Future<void> record(List<Memory> found, {DateTime? now}) {
    final at = now ?? DateTime.now();
    return _db.batch((batch) {
      batch.insertAll(_db.memories, [
        for (final memory in found)
          MemoriesCompanion.insert(
            key: memory.key,
            kind: memory.kind,
            yearsAgo: memory.yearsAgo,
            start: memory.dates.start!,
            end: memory.dates.end!,
            photoCount: memory.count,
            foundAt: at,
          ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  /// Memories not dismissed, the most recently found first, then the most
  /// recent years first.
  Stream<List<Memory>> watchMemories() {
    final query = _db.select(_db.memories)
      ..where((t) => t.dismissed.equals(false))
      ..orderBy([
        (t) => OrderingTerm.desc(t.foundAt),
        (t) => OrderingTerm.asc(t.yearsAgo),
        (t) => OrderingTerm.desc(t.start),
      ]);
    return query.watch().map((rows) => [for (final row in rows) _memory(row)]);
  }

  /// The memory with [key], dismissed or not, or `null`.
  Future<Memory?> find(String key) async {
    final row = await (_db.select(
      _db.memories,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row == null ? null : _memory(row);
  }

  /// Dismisses the memory [key], or brings it back.
  Future<void> setDismissed(String key, {required bool dismissed}) =>
      (_db.update(_db.memories)..where((t) => t.key.equals(key))).write(
        MemoriesCompanion(dismissed: Value(dismissed)),
      );

  /// Every ritual, oldest first.
  Stream<List<Ritual>> watchRituals() {
    final query = _db.select(_db.rituals)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map((rows) => [for (final row in rows) _ritual(row)]);
  }

  /// Every ritual, oldest first, read once.
  Future<List<Ritual>> rituals() => watchRituals().first;

  /// The ritual [id], or `null` when it does not exist (any more).
  Future<Ritual?> ritual(int id) async {
    final row = await (_db.select(
      _db.rituals,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _ritual(row);
  }

  /// Adds [ritual] (its id is ignored); returns the new id.
  Future<int> addRitual(Ritual ritual, {DateTime? now}) {
    final time = ritual.time.valid;
    return _db
        .into(_db.rituals)
        .insert(
          RitualsCompanion.insert(
            content: ritual.content,
            targetId: Value(ritual.targetId),
            repeat: time.repeat,
            day: time.day,
            minute: time.minute,
            enabled: Value(ritual.enabled),
            createdAt: now ?? DateTime.now(),
          ),
        );
  }

  /// Saves the changes to [ritual].
  Future<void> updateRitual(Ritual ritual) {
    final time = ritual.time.valid;
    return (_db.update(
      _db.rituals,
    )..where((t) => t.id.equals(ritual.id))).write(
      RitualsCompanion(
        content: Value(ritual.content),
        targetId: Value(ritual.targetId),
        repeat: Value(time.repeat),
        day: Value(time.day),
        minute: Value(time.minute),
        enabled: Value(ritual.enabled),
      ),
    );
  }

  /// Deletes ritual [id]; returns its row for Undo, or `null`.
  Future<RitualRow?> deleteRitual(int id) => _db.transaction(() async {
    final row = await (_db.select(
      _db.rituals,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    await (_db.delete(_db.rituals)..where((t) => t.id.equals(id))).go();
    return row;
  });

  /// Brings back a ritual removed by [deleteRitual].
  Future<void> restoreRitual(RitualRow row) =>
      _db.into(_db.rituals).insert(row);

  static Memory _memory(MemoryRow row) => Memory(
    key: row.key,
    kind: row.kind,
    yearsAgo: row.yearsAgo,
    dates: DateFilter(start: row.start, end: row.end),
    count: row.photoCount,
  );

  static Ritual _ritual(RitualRow row) => Ritual(
    id: row.id,
    content: row.content,
    targetId: row.targetId,
    time: RecurringTime(repeat: row.repeat, day: row.day, minute: row.minute),
    enabled: row.enabled,
  );
}
