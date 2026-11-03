import 'dart:async';

import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/compact_nav_bar.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/ritual.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:clean_gallery/features/memories/reminder_planner.dart';
import 'package:clean_gallery/features/slideshow/slideshow_actions.dart';
import 'package:clean_gallery/features/slideshow/slideshow_builder.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Rituals (Settings → Rituals): recurring slideshows the user schedules.
///
/// At the chosen time, a notification says the slideshow is ready; tapping
/// it opens the app, which builds the slideshow then. Nothing runs in the
/// background (ADR 0027).
class RitualsScreen extends ConsumerWidget {
  /// Creates the page.
  const RitualsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rituals = ref.watch(ritualsProvider).value;
    final slideshows =
        ref.watch(savedSlideshowsProvider).value ?? const <SavedSlideshow>[];
    final albums = ref.watch(userAlbumsProvider).value ?? const <UserAlbum>[];
    return Scaffold(
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: CompactNavBar.contentInset(context) - 16,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => unawaited(editRitual(context, ref)),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.ritualNew),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 24, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const BackButton(),
                    Expanded(
                      child: Text(
                        l10n.ritualsTitle,
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Text(
                l10n.ritualsHelp,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (rituals != null)
            SliverList.list(
              children: [
                for (final ritual in rituals)
                  ListTile(
                    key: ValueKey(ritual.id),
                    contentPadding: const EdgeInsets.only(left: 20, right: 8),
                    title: Text(
                      ritualName(
                        l10n,
                        ritual,
                        slideshows: slideshows,
                        albums: albums,
                      ),
                    ),
                    subtitle: Text(recurringTimeLabel(context, ritual.time)),
                    onTap: () =>
                        unawaited(editRitual(context, ref, ritual: ritual)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: ritual.enabled,
                          onChanged: (value) => unawaited(
                            _setEnabled(context, ref, ritual, value),
                          ),
                        ),
                        PopupMenuButton<_RitualAction>(
                          tooltip: l10n.ritualMenu,
                          onSelected: (action) => unawaited(switch (action) {
                            _RitualAction.play => playSlideshow(
                              context,
                              RitualSlideshow(ritual.id),
                            ),
                            _RitualAction.delete => _delete(
                              context,
                              ref,
                              ritual,
                            ),
                          }),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _RitualAction.play,
                              child: Text(l10n.ritualPlayNow),
                            ),
                            PopupMenuItem(
                              value: _RitualAction.delete,
                              child: Text(l10n.actionDelete),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          if (rituals != null && rituals.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Text(
                  l10n.ritualsEmpty,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(height: CompactNavBar.contentInset(context) + 80),
          ),
        ],
      ),
    );
  }

  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    Ritual ritual,
    bool enabled,
  ) async {
    if (enabled) await ensureNotifications(context, ref);
    await ref
        .read(memoryRepositoryProvider)
        .updateRitual(ritual.copyWith(enabled: enabled));
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Ritual ritual,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(memoryRepositoryProvider);
    final row = await repository.deleteRitual(ritual.id);
    if (row == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text(l10n.ritualDeletedSnack),
          action: SnackBarAction(
            label: l10n.actionUndo,
            onPressed: () => unawaited(repository.restoreRitual(row)),
          ),
        ),
      );
  }
}

enum _RitualAction { play, delete }

/// Asks for the notification permission when needed (Android 13+), saying
/// so when it is refused; returns whether notifications can be shown.
Future<bool> ensureNotifications(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final allowed = await ref.read(reminderServiceProvider).requestPermission();
  if (!allowed) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text(l10n.notificationsBlocked),
          action: SnackBarAction(
            label: l10n.actionSettings,
            onPressed: () => unawaited(
              ref.read(permissionServiceProvider).openAppSettings(),
            ),
          ),
        ),
      );
  }
  return allowed;
}

/// Creates a ritual, or edits [ritual], in a sheet.
Future<void> editRitual(
  BuildContext context,
  WidgetRef ref, {
  Ritual? ritual,
}) async {
  final edited = await showModalBottomSheet<Ritual>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => RitualSheet(initial: ritual),
  );
  if (edited == null || !context.mounted) return;
  if (edited.enabled) await ensureNotifications(context, ref);
  final repository = ref.read(memoryRepositoryProvider);
  if (ritual == null) {
    await repository.addRitual(edited);
  } else {
    await repository.updateRitual(edited);
  }
}

/// What a ritual plays and when.
class RitualSheet extends ConsumerStatefulWidget {
  /// Creates the sheet, editing [initial] or a new ritual.
  const RitualSheet({this.initial, super.key});

  /// The ritual edited, or `null` for a new one.
  final Ritual? initial;

  @override
  ConsumerState<RitualSheet> createState() => _RitualSheetState();
}

class _RitualSheetState extends ConsumerState<RitualSheet> {
  late Ritual _ritual =
      widget.initial ??
      const Ritual(
        id: 0,
        content: RitualContent.lastWeek,
        time: RecurringTime(
          repeat: Repeat.weekly,
          day: DateTime.sunday,
          minute: 19 * 60,
        ),
      );

  void _setContent(RitualContent content, int? target) {
    setState(() {
      var time = _ritual.time;
      // The usual time of each period, when it is picked.
      if (widget.initial == null && content == RitualContent.lastMonth) {
        time = const RecurringTime(repeat: Repeat.monthly, day: 1, minute: 600);
      } else if (widget.initial == null && content == RitualContent.lastWeek) {
        time = const RecurringTime(
          repeat: Repeat.weekly,
          day: DateTime.sunday,
          minute: 19 * 60,
        );
      }
      _ritual = _ritual.copyWith(
        content: content,
        targetId: target,
        time: time,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final slideshows =
        ref.watch(savedSlideshowsProvider).value ?? const <SavedSlideshow>[];
    final albums = ref.watch(userAlbumsProvider).value ?? const <UserAlbum>[];
    final time = _ritual.time;
    final needsTarget =
        _ritual.content == RitualContent.savedSlideshow ||
        _ritual.content == RitualContent.userAlbum;
    final valid = !needsTarget || _ritual.targetId != null;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? l10n.ritualNew : l10n.ritualEdit,
              style: theme.textTheme.titleLarge,
            ),
            heading(l10n.ritualWhat),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.ritualLastWeek),
                  selected: _ritual.content == RitualContent.lastWeek,
                  onSelected: (_) => _setContent(RitualContent.lastWeek, null),
                ),
                ChoiceChip(
                  label: Text(l10n.ritualLastMonth),
                  selected: _ritual.content == RitualContent.lastMonth,
                  onSelected: (_) => _setContent(RitualContent.lastMonth, null),
                ),
                if (slideshows.isNotEmpty)
                  ChoiceChip(
                    label: Text(l10n.ritualSavedSlideshow),
                    selected: _ritual.content == RitualContent.savedSlideshow,
                    onSelected: (_) => _setContent(
                      RitualContent.savedSlideshow,
                      slideshows.first.id,
                    ),
                  ),
                if (albums.isNotEmpty)
                  ChoiceChip(
                    label: Text(l10n.ritualUserAlbum),
                    selected: _ritual.content == RitualContent.userAlbum,
                    onSelected: (_) =>
                        _setContent(RitualContent.userAlbum, albums.first.id),
                  ),
              ],
            ),
            if (_ritual.content == RitualContent.savedSlideshow)
              _TargetMenu(
                label: l10n.ritualSavedSlideshow,
                value: _ritual.targetId,
                choices: {for (final s in slideshows) s.id: s.title},
                onChanged: (id) =>
                    setState(() => _ritual = _ritual.copyWith(targetId: id)),
              ),
            if (_ritual.content == RitualContent.userAlbum)
              _TargetMenu(
                label: l10n.ritualUserAlbum,
                value: _ritual.targetId,
                choices: {for (final a in albums) a.id: a.name},
                onChanged: (id) =>
                    setState(() => _ritual = _ritual.copyWith(targetId: id)),
              ),
            heading(l10n.ritualWhen),
            RecurringTimeEditor(
              time: time,
              onChanged: (time) =>
                  setState(() => _ritual = _ritual.copyWith(time: time)),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: valid ? () => Navigator.pop(context, _ritual) : null,
              child: Text(l10n.actionSave),
            ),
          ],
        ),
      ),
    );
  }
}

/// Choice of a saved slideshow or album for a ritual.
class _TargetMenu extends StatelessWidget {
  const _TargetMenu({
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final Map<int, String> choices;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownMenu<int>(
        expandedInsets: EdgeInsets.zero,
        label: Text(label),
        initialSelection: choices.containsKey(value) ? value : null,
        onSelected: onChanged,
        dropdownMenuEntries: [
          for (final MapEntry(:key, value: name) in choices.entries)
            DropdownMenuEntry(value: key, label: name),
        ],
      ),
    );
  }
}

/// Weekly or monthly, the day, and the time of a [RecurringTime].
class RecurringTimeEditor extends StatelessWidget {
  /// Creates the editor; [onChanged] gets every change.
  const RecurringTimeEditor({
    required this.time,
    required this.onChanged,
    this.showRepeat = true,
    super.key,
  });

  /// Time shown.
  final RecurringTime time;

  /// Called with the changed time.
  final ValueChanged<RecurringTime> onChanged;

  /// Whether weekly or monthly can be changed here.
  final bool showRepeat;

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.minute ~/ 60, minute: time.minute % 60),
    );
    if (picked != null) {
      onChanged(time.copyWith(minute: picked.hour * 60 + picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final weekly = time.repeat == Repeat.weekly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showRepeat) ...[
          SegmentedButton<Repeat>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: Repeat.weekly,
                label: Text(l10n.repeatWeekly),
              ),
              ButtonSegment(
                value: Repeat.monthly,
                label: Text(l10n.repeatMonthly),
              ),
            ],
            selected: {time.repeat},
            onSelectionChanged: (value) => onChanged(
              RecurringTime(
                repeat: value.single,
                day: value.single == Repeat.weekly ? DateTime.sunday : 1,
                minute: time.minute,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: DropdownMenu<int>(
                expandedInsets: EdgeInsets.zero,
                label: Text(l10n.ritualDay),
                initialSelection: time.valid.day,
                // Rebuilt with the other choices when the repeat changes.
                key: ValueKey(time.repeat),
                onSelected: (day) {
                  if (day != null) onChanged(time.copyWith(day: day));
                },
                dropdownMenuEntries: weekly
                    ? [
                        for (var day = 1; day <= 7; day++)
                          DropdownMenuEntry(
                            value: day,
                            label: weekdayName(locale, day, capitalized: true),
                          ),
                      ]
                    : [
                        for (
                          var day = 1;
                          day <= RecurringTime.maxDayOfMonth;
                          day++
                        )
                          DropdownMenuEntry(value: day, label: '$day'),
                      ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => unawaited(_pickTime(context)),
              icon: const Icon(Icons.schedule_rounded),
              label: Text(timeLabel(context, time.minute)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Name of the weekday [day] (1 = Monday) in [locale], as written in a
/// sentence ("dimanche" in French), or [capitalized] for a list.
String weekdayName(String locale, int day, {bool capitalized = false}) {
  // 1 January 2024 was a Monday.
  final name = DateFormat.EEEE(locale).format(DateTime(2024, 1, day));
  if (!capitalized || name.isEmpty) return name;
  return name[0].toUpperCase() + name.substring(1);
}

/// [minute] past midnight as the user's time format, e.g. "19:00".
String timeLabel(BuildContext context, int minute) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// [time] in words, e.g. "Every Sunday at 19:00".
String recurringTimeLabel(BuildContext context, RecurringTime time) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final at = timeLabel(context, time.minute);
  return switch (time.repeat) {
    Repeat.weekly => l10n.repeatEveryWeekday(
      weekdayName(locale, time.valid.day),
      at,
    ),
    Repeat.monthly => l10n.repeatEveryMonthDay(time.valid.day, at),
  };
}
