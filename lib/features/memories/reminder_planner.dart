import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:clean_gallery/analysis/schedule.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/memory.dart';
import 'package:clean_gallery/domain/ritual.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:clean_gallery/features/memories/memory_providers.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:clean_gallery/platform/reminder_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reminder_planner.g.dart';

/// Payload of the memories notification.
const memoriesPayload = 'memories';

/// Payload of the notification of ritual [id].
String ritualPayload(int id) => 'ritual:$id';

/// Ritual id of a notification [payload], or `null` for another payload.
int? ritualIdOf(String payload) => payload.startsWith('ritual:')
    ? int.tryParse(payload.substring('ritual:'.length))
    : null;

/// Notification ids: memories from [_memoryIds], ritual `r` from
/// `_ritualIds + r * 16`, one per occurrence set ahead.
const _memoryIds = 1000;
const _ritualIds = 100000;

/// The notifications to set for the memories and [rituals], strictly after
/// [now], earliest first.
///
/// Memory notifications are set only for the times when [memoriesOn] finds
/// memories, so none says "Your memories are ready" for nothing. Ritual
/// notifications are set for every time; the slideshow is built when one
/// is tapped. [ritualName] names what a ritual plays.
Future<List<Reminder>> planReminders({
  required AppSettings settings,
  required List<Ritual> rituals,
  required DateTime now,
  required AppLocalizations l10n,
  required Future<List<Memory>> Function(DateTime day) memoriesOn,
  required String Function(Ritual ritual) ritualName,
}) async {
  final reminders = <Reminder>[];
  final memoriesTime = settings.memoriesTime;
  if (settings.memoriesNotify && memoriesTime != null) {
    final times = nextOccurrences(
      memoriesTime,
      from: now,
      count: occurrencesAhead(memoriesTime.repeat),
    );
    for (final (i, at) in times.indexed) {
      final memories = await memoriesOn(at);
      if (memories.isEmpty) continue;
      final first = memories.first;
      reminders.add(
        Reminder(
          id: _memoryIds + i,
          at: at,
          title: l10n.memoriesNotificationTitle,
          body: '${memoryTitle(l10n, first)} · ${l10n.photoCount(first.count)}',
          payload: memoriesPayload,
        ),
      );
    }
  }
  for (final ritual in rituals) {
    if (!ritual.enabled) continue;
    final times = nextOccurrences(
      ritual.time,
      from: now,
      count: occurrencesAhead(ritual.time.repeat),
    );
    for (final (i, at) in times.indexed) {
      reminders.add(
        Reminder(
          id: _ritualIds + ritual.id * 16 + i,
          at: at,
          title: l10n.ritualNotificationTitle,
          body: ritualName(ritual),
          payload: ritualPayload(ritual.id),
        ),
      );
    }
  }
  return reminders..sort((a, b) => a.at.compareTo(b.at));
}

/// Title of [memory], e.g. "This week, 1 year ago".
String memoryTitle(AppLocalizations l10n, Memory memory) =>
    switch (memory.kind) {
      MemoryKind.onThisDay => l10n.memoryOnThisDay(memory.yearsAgo),
      MemoryKind.thisWeek => l10n.memoryThisWeek(memory.yearsAgo),
    };

/// What [ritual] plays, e.g. "The week's photos" or an album's name;
/// [slideshows] and [albums] name its target.
String ritualName(
  AppLocalizations l10n,
  Ritual ritual, {
  required List<SavedSlideshow> slideshows,
  required List<UserAlbum> albums,
}) => switch (ritual.content) {
  RitualContent.lastWeek => l10n.ritualLastWeek,
  RitualContent.lastMonth => l10n.ritualLastMonth,
  RitualContent.savedSlideshow =>
    slideshows.where((s) => s.id == ritual.targetId).firstOrNull?.title ??
        l10n.ritualTargetMissing,
  RitualContent.userAlbum =>
    albums.where((a) => a.id == ritual.targetId).firstOrNull?.name ??
        l10n.ritualTargetMissing,
};

/// Keeps the scheduled notifications in line with the settings and the
/// rituals: sets them again once the media index is ready at launch, and
/// whenever the memories settings, the language, the rituals or the names
/// they show change.
///
/// Watched by the home shell, so it lives as long as the app.
@Riverpod(keepAlive: true)
class ReminderSync extends _$ReminderSync {
  /// Incremented by each plan; older plans drop their result.
  var _generation = 0;

  @override
  void build() {
    ref
      ..listen(mediaIndexProvider.select((s) => s.ready), (_, _) => _later())
      ..listen(
        appSettingsControllerProvider.select(
          (s) => (
            s.memories,
            s.memoriesWeekday,
            s.memoriesMonthDay,
            s.memoriesMinute,
            s.memoriesNotify,
            s.language,
          ),
        ),
        (_, _) => _later(),
      )
      ..listen(ritualsProvider, (_, _) => _later())
      ..listen(savedSlideshowsProvider, (_, _) => _later())
      ..listen(userAlbumsProvider, (_, _) => _later())
      ..onDispose(() => _timer?.cancel());
    _later();
  }

  Timer? _timer;

  /// Plans once the changes settle: several streams change together at
  /// launch.
  void _later() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () => unawaited(_plan()));
  }

  /// Plans and sets the notifications now.
  Future<void> refresh() => _plan();

  Future<void> _plan() async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    // Read before any gap: the provider may be gone after one. The lists
    // are those already watched; until they load, their listeners plan
    // again.
    final settings = ref.read(appSettingsControllerProvider);
    final ready = ref.read(mediaIndexProvider).ready;
    final finder = ref.read(memoryFinderProvider);
    final service = ref.read(reminderServiceProvider);
    final rituals = ref.read(ritualsProvider).value;
    final slideshows = ref.read(savedSlideshowsProvider).value;
    final albums = ref.read(userAlbumsProvider).value;
    if (rituals == null || slideshows == null || albums == null) return;
    final l10n = _localizations(settings.language);
    final reminders = await planReminders(
      settings: settings,
      rituals: rituals,
      now: DateTime.now(),
      l10n: l10n,
      // Before the first index, no memory can be found.
      memoriesOn: (day) async => ready ? await finder.find(day) : const [],
      ritualName: (ritual) =>
          ritualName(l10n, ritual, slideshows: slideshows, albums: albums),
    );
    if (!ref.mounted || generation != _generation) return;
    await service.schedule(reminders);
  }

  static AppLocalizations _localizations(LanguagePreference language) {
    final locale = switch (language) {
      LanguagePreference.english => const Locale('en'),
      LanguagePreference.french => const Locale('fr'),
      LanguagePreference.system => PlatformDispatcher.instance.locale,
    };
    return AppLocalizations.delegate.isSupported(locale)
        ? lookupAppLocalizations(Locale(locale.languageCode))
        : lookupAppLocalizations(const Locale('en'));
  }
}
