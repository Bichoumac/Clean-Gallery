import 'dart:async';

import 'package:clean_gallery/core/media/media_actions.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/features/swipe/swipe_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'swipe_session.g.dart';

/// One decision of a swipe session.
typedef SwipeDecision = ({MediaItem item, SwipeAction action});

/// State of a swipe session: the cards left and the decisions taken.
@immutable
final class SwipeSessionState {
  /// Creates a state.
  const SwipeSessionState({
    required this.remaining,
    required this.decisions,
    this.returned,
  });

  /// Cards still to sort, the current one first.
  final List<MediaItem> remaining;

  /// Decisions taken, oldest first, including those of earlier visits.
  final List<SwipeDecision> decisions;

  /// The decision just undone: its card is back on top and comes back
  /// from the side it left.
  final SwipeDecision? returned;

  /// Card shown, or `null` once every card is sorted.
  MediaItem? get current => remaining.isEmpty ? null : remaining.first;

  /// Cards sorted so far.
  int get done => decisions.length;

  /// Cards of the session, sorted or not.
  int get total => decisions.length + remaining.length;

  /// Whether every card is sorted.
  bool get finished => remaining.isEmpty;

  /// Decisions of [action].
  List<MediaItem> decided(SwipeAction action) => [
    for (final decision in decisions)
      if (decision.action == action) decision.item,
  ];
}

/// A swipe session on [SwipeSource]: left trashes, right keeps, the heart
/// keeps as a favorite, and **Undo** takes back the last decision, as many
/// times as needed.
///
/// Decisions are saved in `swipe_history` as they are taken, so leaving
/// and coming back resumes the session. Trashing goes through the app
/// trash, so undoing restores the item. See `docs/features/swipe.md`.
@riverpod
class SwipeSession extends _$SwipeSession {
  /// Database writes, one after the other: an undo right after a swipe
  /// must remove that swipe, not the one before.
  Future<void> _writes = Future.value();

  @override
  Future<SwipeSessionState> build(SwipeSource source) async {
    final index = ref.read(mediaIndexRepositoryProvider);
    final selection = ref.read(swipeSelectionProvider(source));
    final rows = await ref.read(swipeRepositoryProvider).decisions(source.key);
    final trashed = await ref.read(trashRepositoryProvider).trashedIds();
    final decidedIds = {for (final row in rows) '${row.assetId}'};
    final items = await index.load(selection);
    final decidedItems = rows.isEmpty
        ? const <String, MediaItem>{}
        : {
            for (final item in await index.load(
              MediaSelection(ids: decidedIds.toList()),
            ))
              item.id: item,
          };
    return SwipeSessionState(
      remaining: [
        for (final item in items)
          if (!decidedIds.contains(item.id) && !trashed.contains(item.id)) item,
      ],
      decisions: [
        for (final row in rows)
          if (decidedItems['${row.assetId}'] case final item?)
            (item: item, action: row.action),
      ],
    );
  }

  /// Applies [action] to the current card and shows the next one.
  ///
  /// Returns `false` when the user declined to add a favorite in the
  /// system prompt; the card is kept anyway.
  Future<bool> decide(SwipeAction action) async {
    final session = state.value;
    final item = session?.current;
    if (session == null || item == null) return true;
    final order = session.decisions.length;
    state = AsyncData(
      SwipeSessionState(
        remaining: session.remaining.sublist(1),
        decisions: [...session.decisions, (item: item, action: action)],
      ),
    );
    await _write(
      () => ref
          .read(swipeRepositoryProvider)
          .record(
            source.key,
            order: order,
            assetId: int.parse(item.id),
            action: action,
          ),
    );
    final actions = ref.read(mediaActionsProvider);
    switch (action) {
      case SwipeAction.keep:
        return true;
      case SwipeAction.trash:
        await actions.trash([item]);
        return true;
      case SwipeAction.favorite:
        if (item.isFavorite) return true;
        try {
          return await actions.setFavorite([item], favorite: true);
        } on PlatformException {
          return false;
        }
    }
  }

  /// Takes back the last decision: its card comes back on top, a trashed
  /// item is restored and a new favorite is unmarked.
  Future<void> undo() async {
    final session = state.value;
    if (session == null || session.decisions.isEmpty) return;
    final last = session.decisions.last;
    state = AsyncData(
      SwipeSessionState(
        remaining: [last.item, ...session.remaining],
        decisions: session.decisions.sublist(0, session.decisions.length - 1),
        returned: last,
      ),
    );
    await _write(
      () => ref.read(swipeRepositoryProvider).removeLast(source.key),
    );
    final actions = ref.read(mediaActionsProvider);
    switch (last.action) {
      case SwipeAction.keep:
        break;
      case SwipeAction.trash:
        await actions.restore([last.item.id]);
      case SwipeAction.favorite:
        if (!last.item.isFavorite) {
          try {
            await actions.setFavorite([last.item], favorite: false);
          } on PlatformException {
            // The heart stays; nothing else to undo.
          }
        }
    }
  }

  /// Forgets the decisions of this session and starts it again with the
  /// items still in the library. Trashed items stay in the trash.
  Future<void> restart() async {
    await _write(() => ref.read(swipeRepositoryProvider).clear(source.key));
    ref.invalidateSelf();
  }

  Future<void> _write(Future<void> Function() write) {
    final next = _writes.then((_) => write());
    // A failed write must not block the next ones.
    _writes = next.catchError((Object _) {});
    return next.whenComplete(() {
      if (ref.mounted) ref.invalidate(swipeProgressProvider);
    });
  }
}
