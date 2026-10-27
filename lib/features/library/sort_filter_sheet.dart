import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Ready-made date ranges offered in the sheet.
enum DatePreset {
  /// The last 7 days, today included.
  last7Days,

  /// The last 30 days, today included.
  last30Days,

  /// From January 1st of the current year.
  thisYear,

  /// The whole previous calendar year.
  lastYear,
}

/// Range of [preset] relative to [now].
DateFilter datePresetRange(DatePreset preset, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (preset) {
    DatePreset.last7Days => DateFilter.days(
      today.subtract(const Duration(days: 6)),
      today,
    ),
    DatePreset.last30Days => DateFilter.days(
      today.subtract(const Duration(days: 29)),
      today,
    ),
    DatePreset.thisYear => DateFilter(start: DateTime(now.year)),
    DatePreset.lastYear => DateFilter(
      start: DateTime(now.year - 1),
      end: DateTime(now.year),
    ),
  };
}

/// Preset matching [dates] today, if any.
DatePreset? matchingPreset(DateFilter? dates, DateTime now) {
  if (dates == null) return null;
  for (final preset in DatePreset.values) {
    if (datePresetRange(preset, now) == dates) return preset;
  }
  return null;
}

/// Label of a date range: the preset name, or "12 Mar 2026 – 20 Apr 2026".
String dateFilterLabel(BuildContext context, DateFilter dates, DateTime now) {
  final l10n = AppLocalizations.of(context);
  return switch (matchingPreset(dates, now)) {
    DatePreset.last7Days => l10n.filterLast7Days,
    DatePreset.last30Days => l10n.filterLast30Days,
    DatePreset.thisYear => l10n.filterThisYear,
    DatePreset.lastYear => l10n.filterLastYear,
    null => _rangeLabel(context, dates),
  };
}

String _rangeLabel(BuildContext context, DateFilter dates) {
  final format = DateFormat.yMMMd(
    Localizations.localeOf(context).toLanguageTag(),
  );
  final start = dates.start;
  final end = dates.end;
  // `end` is exclusive: show the last included day.
  final last = end?.subtract(const Duration(days: 1));
  if (start != null && last != null) {
    return '${format.format(start)} – ${format.format(last)}';
  }
  if (start != null) return '≥ ${format.format(start)}';
  return '≤ ${format.format(last!)}';
}

/// Label of a sort order, e.g. "Size · Largest first".
String sortLabel(BuildContext context, MediaSort sort) {
  final l10n = AppLocalizations.of(context);
  final field = switch (sort.field) {
    MediaSortField.date => l10n.sortDate,
    MediaSortField.name => l10n.sortName,
    MediaSortField.size => l10n.sortSize,
    MediaSortField.duration => l10n.sortDuration,
  };
  final direction = _directionLabel(
    l10n,
    sort.field,
    descending: sort.descending,
  );
  return '$field · $direction';
}

/// Label of one direction of [field], e.g. "Newest first" or "A to Z".
String _directionLabel(
  AppLocalizations l10n,
  MediaSortField field, {
  required bool descending,
}) => switch ((field, descending)) {
  (MediaSortField.date, true) => l10n.sortNewest,
  (MediaSortField.date, false) => l10n.sortOldest,
  (MediaSortField.name, true) => l10n.sortZToA,
  (MediaSortField.name, false) => l10n.sortAToZ,
  (MediaSortField.size, true) => l10n.sortLargest,
  (MediaSortField.size, false) => l10n.sortSmallest,
  (MediaSortField.duration, true) => l10n.sortLongest,
  (MediaSortField.duration, false) => l10n.sortShortest,
};

/// Opens the sort and date filter sheet for the timeline of [base].
Future<void> showSortFilterSheet(BuildContext context, MediaSelection base) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SortFilterSheet(base: base),
  );
}

/// Sort order and date range of one timeline. Changes apply immediately.
class SortFilterSheet extends ConsumerWidget {
  /// Creates the sheet for the timeline of [base].
  const SortFilterSheet({required this.base, this.now, super.key});

  /// Base selection of the timeline (tab or album).
  final MediaSelection base;

  /// Current time; injectable for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final selection = ref.watch(viewSelectionProvider(base));
    final notifier = ref.read(viewSelectionProvider(base).notifier);
    final sort = selection.sort;
    final today = now ?? DateTime.now();
    final preset = matchingPreset(selection.dates, today);
    final customDates = selection.dates != null && preset == null;
    // Duration only makes sense when videos can be in the list.
    final fields = [
      MediaSortField.date,
      MediaSortField.name,
      MediaSortField.size,
      if (base.filter != MediaFilter.photos &&
          base.filter != MediaFilter.camera &&
          base.filter != MediaFilter.screenshots)
        MediaSortField.duration,
    ];
    String direction({required bool descending}) =>
        _directionLabel(l10n, sort.field, descending: descending);

    Future<void> pickCustomRange() async {
      final current = selection.dates;
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(1990),
        lastDate: today,
        initialDateRange: current?.start != null && current?.end != null
            ? DateTimeRange(
                start: current!.start!,
                end: current.end!.subtract(const Duration(days: 1)),
              )
            : null,
      );
      if (picked != null) {
        notifier.setDates(DateFilter.days(picked.start, picked.end));
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.sortTitle, style: textTheme.titleLarge),
                ),
                TextButton(
                  onPressed: selection == base ? null : notifier.reset,
                  child: Text(l10n.filterReset),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final field in fields)
                  ChoiceChip(
                    label: Text(switch (field) {
                      MediaSortField.date => l10n.sortDate,
                      MediaSortField.name => l10n.sortName,
                      MediaSortField.size => l10n.sortSize,
                      MediaSortField.duration => l10n.sortDuration,
                    }),
                    selected: sort.field == field,
                    onSelected: (_) => notifier.setSort(
                      // Names read best A to Z; other fields biggest first.
                      MediaSort(
                        field: field,
                        descending: field != MediaSortField.name,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(direction(descending: true)),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(direction(descending: false)),
                  ),
                ],
                selected: {sort.descending},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    notifier.setSort(sort.copyWith(descending: value.single)),
              ),
            ),
            const SizedBox(height: 24),
            Text(l10n.filterPeriod, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.filterAllTime),
                  selected: selection.dates == null,
                  onSelected: (_) => notifier.setDates(null),
                ),
                for (final p in DatePreset.values)
                  ChoiceChip(
                    label: Text(switch (p) {
                      DatePreset.last7Days => l10n.filterLast7Days,
                      DatePreset.last30Days => l10n.filterLast30Days,
                      DatePreset.thisYear => l10n.filterThisYear,
                      DatePreset.lastYear => l10n.filterLastYear,
                    }),
                    selected: preset == p,
                    onSelected: (_) =>
                        notifier.setDates(datePresetRange(p, today)),
                  ),
                ChoiceChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    customDates
                        ? _rangeLabel(context, selection.dates!)
                        : l10n.filterCustom,
                  ),
                  selected: customDates,
                  onSelected: (_) => pickCustomRange(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
