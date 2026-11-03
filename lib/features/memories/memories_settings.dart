import 'dart:async';

import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/ritual.dart';
import 'package:clean_gallery/features/memories/rituals_screen.dart';
import 'package:clean_gallery/features/slideshow/slideshow_actions.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The *Slideshows and memories* settings: how often memories come, their
/// notification and its day and time, the rituals, and the slideshow
/// defaults.
class MemoriesSettings extends ConsumerWidget {
  /// Creates the settings.
  const MemoriesSettings({super.key});

  Future<void> _setNotify(
    BuildContext context,
    WidgetRef ref, {
    required bool value,
  }) async {
    final controller = ref.read(appSettingsControllerProvider.notifier);
    if (value && !await ensureNotifications(context, ref)) return;
    await controller.setMemoriesNotify(value: value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsControllerProvider);
    final controller = ref.read(appSettingsControllerProvider.notifier);
    final time = settings.memoriesTime;
    final rituals = ref.watch(ritualsProvider).value ?? const <Ritual>[];
    final active = rituals.where((r) => r.enabled).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.settingsMemories, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        SegmentedButton<MemoriesFrequency>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: MemoriesFrequency.off,
              label: Text(l10n.memoriesOff),
            ),
            ButtonSegment(
              value: MemoriesFrequency.weekly,
              label: Text(l10n.repeatWeekly),
            ),
            ButtonSegment(
              value: MemoriesFrequency.monthly,
              label: Text(l10n.repeatMonthly),
            ),
          ],
          selected: {settings.memories},
          onSelectionChanged: (value) =>
              unawaited(controller.setMemories(value.single)),
        ),
        if (time != null) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsMemoriesNotify),
            subtitle: Text(
              settings.memoriesNotify
                  ? recurringTimeLabel(context, time)
                  : l10n.settingsMemoriesNotifyHelp,
            ),
            value: settings.memoriesNotify,
            onChanged: (value) =>
                unawaited(_setNotify(context, ref, value: value)),
          ),
          if (settings.memoriesNotify)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RecurringTimeEditor(
                time: time,
                showRepeat: false,
                onChanged: (time) =>
                    unawaited(controller.setMemoriesTime(time)),
              ),
            ),
        ],
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_repeat_rounded),
          title: Text(l10n.ritualsTitle),
          subtitle: Text(
            rituals.isEmpty
                ? l10n.settingsRitualsHelp
                : l10n.settingsRitualsCount(active),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => unawaited(context.push(AppRoutes.rituals)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tune_rounded),
          title: Text(l10n.slideshowDefaults),
          subtitle: Text(l10n.settingsSlideshowDefaultsHelp),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () =>
              unawaited(showSlideshowOptions(context, ref, asDefaults: true)),
        ),
      ],
    );
  }
}
