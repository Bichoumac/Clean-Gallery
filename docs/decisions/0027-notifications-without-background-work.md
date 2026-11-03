# ADR 0027 — Memory and ritual notifications without background work

How the weekly memories notification and the rituals reach the user while nothing runs in the background.

Last updated: 2026-11-03 — Milestone M9

- **Status**: Accepted (product owner, 2026-11-01, Q5; AGENTS.md rule 12)
- **Date**: 2026-11-03

## Context

Memories come once a week by default, and rituals are slideshows the user schedules ("every Sunday at 7 pm: the week's photos"). The product owner asked for a small notification at that time and **no background task**: no code may read photos or the database while the app is closed. Android removes alarms on reboot, and an app may only post notifications on Android 13+ once the user allows it.

## Decision

- **The app plans, the platform only shows.** While the app is open, `ReminderSync` works out the next notifications (`planReminders`): 8 weeks or 6 months ahead per ritual, and, for memories, only the times when `MemoryFinder` finds memories for that day (so no "Your memories are ready" for nothing). It hands them over with their time, title, text and payload.
- **Android side** (`Reminders.kt`): the list is kept in the app's preferences; **one inexact alarm** (`setAndAllowWhileIdle`) is set for the earliest. When it rings, `ReminderReceiver` shows the notifications due and sets the alarm for the next. After a reboot or an app update (`BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`) the same receiver only sets the alarm again. It reads that list and nothing else.
- **Tapping** a notification opens the app with its payload (`memories`, `ritual:<id>`); the app builds the slideshow then, from the index as it is at that moment.
- The list is planned again at every launch, and whenever the memories settings, the language, the rituals or the names they show change, so the texts stay right.
- **Permission**: `POST_NOTIFICATIONS` is asked when the user turns on the memories notification or a ritual, never at onboarding. Refused, the memory card still shows in the app.
- **Inexact on purpose**: no `SCHEDULE_EXACT_ALARM` ("Alarms & reminders") permission; a notification may come a few minutes late.

## Alternatives considered

- **WorkManager / a periodic job** computing memories in the background: what the product owner ruled out.
- **`flutter_local_notifications` with `timezone`**: does the same scheduling with a boot receiver of its own, but adds two packages, core library desugaring and a time zone database for what is about 150 lines of Kotlin; computing the times in Dart with local `DateTime` fields already keeps 7 pm at 7 pm across daylight saving changes.
- **Repeating alarms** (one per ritual): they cannot skip the weeks without memories, and each needs its own alarm.

## Consequences

- When the app is not opened for over two months, weekly notifications stop until the next launch; monthly ones after six months.
- Notifications planned for memories use the library as it was at the last launch; the slideshow itself is built from the library at tap time.
- A test checks that the receiver and `Reminders.kt` do not touch MediaStore or the database.
