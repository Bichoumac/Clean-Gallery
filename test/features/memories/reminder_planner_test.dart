import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/memory.dart';
import 'package:clean_gallery/domain/ritual.dart';
import 'package:clean_gallery/features/memories/reminder_planner.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  // Tuesday 3 November 2026, 10:00.
  final now = DateTime(2026, 11, 3, 10);
  final memory = Memory(
    key: 'thisWeek:2025-11-03',
    kind: MemoryKind.thisWeek,
    yearsAgo: 1,
    dates: DateFilter.days(DateTime(2025, 11, 3), DateTime(2025, 11, 9)),
    count: 24,
  );

  test('memory notifications only on days that have memories', () async {
    final checked = <DateTime>[];
    final reminders = await planReminders(
      settings: const AppSettings(memoriesNotify: true),
      rituals: const [],
      now: now,
      l10n: l10n,
      memoriesOn: (day) async {
        checked.add(day);
        // Only the second Sunday has memories.
        return day == DateTime(2026, 11, 15, 19) ? [memory] : const [];
      },
      ritualName: (_) => '',
    );
    expect(checked, hasLength(8));
    expect(checked.first, DateTime(2026, 11, 8, 19));
    expect(reminders, hasLength(1));
    expect(reminders.single.at, DateTime(2026, 11, 15, 19));
    expect(reminders.single.payload, memoriesPayload);
    expect(reminders.single.body, 'This week, 1 year ago · 24 photos');
  });

  test('no memory notification while it is off or memories are off', () async {
    for (final settings in [
      const AppSettings(),
      const AppSettings(memoriesNotify: true, memories: MemoriesFrequency.off),
    ]) {
      final reminders = await planReminders(
        settings: settings,
        rituals: const [],
        now: now,
        l10n: l10n,
        memoriesOn: (_) async => [memory],
        ritualName: (_) => '',
      );
      expect(reminders, isEmpty);
    }
  });

  test('every time of an enabled ritual, earliest first', () async {
    const monthly = Ritual(
      id: 2,
      content: RitualContent.lastMonth,
      time: RecurringTime(repeat: Repeat.monthly, day: 1, minute: 600),
    );
    const off = Ritual(
      id: 3,
      content: RitualContent.lastWeek,
      time: RecurringTime(repeat: Repeat.weekly, day: 7, minute: 600),
      enabled: false,
    );
    final reminders = await planReminders(
      settings: const AppSettings(),
      rituals: const [monthly, off],
      now: now,
      l10n: l10n,
      memoriesOn: (_) async => const [],
      ritualName: (ritual) =>
          ritualName(l10n, ritual, slideshows: const [], albums: const []),
    );
    expect(reminders, hasLength(6));
    expect(reminders.first.at, DateTime(2026, 12, 1, 10));
    expect(reminders.first.payload, ritualPayload(2));
    expect(ritualIdOf(reminders.first.payload), 2);
    expect(reminders.first.title, 'Your slideshow is ready');
    expect(reminders.first.body, "The month's photos");
    expect({for (final r in reminders) r.id}, hasLength(6));
    expect(ritualIdOf(memoriesPayload), isNull);
  });
}
