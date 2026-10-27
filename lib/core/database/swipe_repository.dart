import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:drift/drift.dart';

/// One decision of a swipe session: the item and what was done with it.
typedef SwipeDecisionRow = ({int assetId, SwipeAction action});

/// Decisions of the swipe sessions, stored in the `swipe_history` table so
/// a session resumes where the user left it.
///
/// A session is identified by its source (e.g. `all`, `month:2024-03`):
/// one session per source. See `docs/features/swipe.md`.
final class SwipeRepository {
  /// Creates the repository on [_db].
  const SwipeRepository(this._db);

  final AppDatabase _db;

  /// Decisions of [session], in the order they were taken.
  Future<List<SwipeDecisionRow>> decisions(String session) async {
    final history = _db.swipeHistory;
    final query = _db.select(history)
      ..where((t) => t.session.equals(session))
      ..orderBy([(t) => OrderingTerm.asc(t.order)]);
    return [
      for (final row in await query.get())
        (assetId: row.assetId, action: row.action),
    ];
  }

  /// Records [action] on the item [assetId] as decision number [order] of
  /// [session].
  Future<void> record(
    String session, {
    required int order,
    required int assetId,
    required SwipeAction action,
  }) => _db
      .into(_db.swipeHistory)
      .insert(
        SwipeHistoryCompanion.insert(
          session: session,
          order: order,
          assetId: assetId,
          action: action,
        ),
      );

  /// Forgets the last decision of [session] (undo).
  Future<void> removeLast(String session) async {
    final history = _db.swipeHistory;
    final last =
        await (_db.select(history)
              ..where((t) => t.session.equals(session))
              ..orderBy([(t) => OrderingTerm.desc(t.order)])
              ..limit(1))
            .getSingleOrNull();
    if (last == null) return;
    await (_db.delete(history)..where((t) => t.id.equals(last.id))).go();
  }

  /// Forgets every decision of [session], to start it over.
  Future<void> clear(String session) => (_db.delete(
    _db.swipeHistory,
  )..where((t) => t.session.equals(session))).go();

  /// Number of decisions of each session that has any, by session.
  Future<Map<String, int>> progress() async {
    final history = _db.swipeHistory;
    final count = history.id.count();
    final query = _db.selectOnly(history)
      ..addColumns([history.session, count])
      ..groupBy([history.session]);
    return {
      for (final row in await query.get())
        row.read(history.session)!: row.read(count)!,
    };
  }
}
