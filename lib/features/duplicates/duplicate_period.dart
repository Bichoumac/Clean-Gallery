import 'dart:async';

import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// [day] as a short date of the current locale, e.g. *12 janv. 2024*.
String formatPeriodDay(BuildContext context, DateTime day) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(day);

/// The last day of [period], included, or `null` without an end.
DateTime? periodLastDay(DateFilter period) {
  final end = period.end;
  if (end == null) return null;
  return DateTime(end.year, end.month, end.day - 1);
}

/// The duplicate period as a short text: *12 janv. 2024 – aujourd'hui*.
String formatPeriod(BuildContext context, DateFilter period) {
  final l10n = AppLocalizations.of(context);
  final start = period.start;
  final last = periodLastDay(period);
  return l10n.periodRange(
    start == null ? l10n.periodNoStart : formatPeriodDay(context, start),
    last == null ? l10n.periodNoEnd : formatPeriodDay(context, last),
  );
}

/// The period duplicates and similar photos are looked for in: a first and
/// a last day, each optional, and a way back to the whole library
/// (issue #19).
class DuplicatePeriodSettings extends ConsumerWidget {
  /// Creates the setting.
  const DuplicatePeriodSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final period = ref.watch(
      appSettingsControllerProvider.select((s) => s.duplicatePeriod),
    );
    final controller = ref.read(appSettingsControllerProvider.notifier);
    final start = period?.start;
    final last = period == null ? null : periodLastDay(period);
    final today = DateUtils.dateOnly(DateTime.now());

    void save(DateTime? first, DateTime? lastDay) => unawaited(
      controller.setDuplicatePeriod(
        first == null && lastDay == null
            ? null
            : DateFilter(
                start: first,
                end: lastDay == null
                    ? null
                    : DateTime(lastDay.year, lastDay.month, lastDay.day + 1),
              ),
      ),
    );

    Future<void> pickStart() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: start ?? last ?? today,
        firstDate: DateTime(1990),
        lastDate: last ?? today,
        helpText: l10n.periodFrom,
      );
      if (picked != null) save(picked, last);
    }

    Future<void> pickEnd() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: last ?? today,
        firstDate: start ?? DateTime(1990),
        lastDate: today,
        helpText: l10n.periodTo,
      );
      if (picked != null) save(start, picked);
    }

    Widget bound({
      required String label,
      required DateTime? day,
      required String unset,
      required VoidCallback onPick,
      required VoidCallback onClear,
    }) {
      final value = day == null ? unset : formatPeriodDay(context, day);
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event_rounded),
        title: Text(label),
        subtitle: Text(
          value,
          style: day == null
              ? null
              : TextStyle(color: theme.colorScheme.primary),
        ),
        onTap: onPick,
        trailing: day == null
            ? null
            : IconButton(
                tooltip: l10n.periodClear(label),
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settingsDuplicatePeriod, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            l10n.settingsDuplicatePeriodHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          bound(
            label: l10n.periodFrom,
            day: start,
            unset: l10n.periodNoStart,
            onPick: () => unawaited(pickStart()),
            onClear: () => save(null, last),
          ),
          bound(
            label: l10n.periodTo,
            day: last,
            unset: l10n.periodNoEnd,
            onPick: () => unawaited(pickEnd()),
            onClear: () => save(start, null),
          ),
          if (period != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => save(null, null),
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(l10n.periodReset),
              ),
            ),
        ],
      ),
    );
  }
}
