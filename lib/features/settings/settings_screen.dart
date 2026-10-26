import 'dart:async';

import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/home_shell.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_screen.g.dart';

/// Permission levels shown in Settings.
typedef PermissionStatus = ({
  MediaAccess media,
  bool location,
  bool mediaManagement,
});

/// Current permission levels, read without prompting. Invalidated when the
/// app comes back from the system settings.
@riverpod
Future<PermissionStatus> permissionStatus(Ref ref) async {
  final permissions = ref.watch(permissionServiceProvider);
  final bridge = ref.watch(platformBridgeProvider);
  return (
    media: await permissions.mediaAccess(),
    location: await permissions.hasLocationAccess(),
    mediaManagement: await bridge.isMediaManagementGranted(),
  );
}

/// Settings tab: display, trash, sharing and permissions.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates the Settings tab.
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Permissions may have changed in the system settings.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref
          ..invalidate(permissionStatusProvider)
          ..invalidate(mediaAccessProvider);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsControllerProvider);
    final controller = ref.read(appSettingsControllerProvider.notifier);

    return TabPage(
      title: l10n.navSettings,
      children: [
        _Section(
          title: l10n.settingsDisplay,
          children: [
            _Labeled(
              label: l10n.settingsTheme,
              child: SegmentedButton<ThemePreference>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ThemePreference.system,
                    label: Text(l10n.themeSystem),
                  ),
                  ButtonSegment(
                    value: ThemePreference.light,
                    label: Text(l10n.themeLight),
                  ),
                  ButtonSegment(
                    value: ThemePreference.dark,
                    label: Text(l10n.themeDark),
                  ),
                ],
                selected: {settings.theme},
                onSelectionChanged: (value) =>
                    controller.setTheme(value.single),
              ),
            ),
            _Labeled(
              label: l10n.settingsLanguage,
              child: SegmentedButton<LanguagePreference>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: LanguagePreference.system,
                    label: Text(l10n.languageSystem),
                  ),
                  ButtonSegment(
                    value: LanguagePreference.english,
                    label: Text(l10n.languageEnglish),
                  ),
                  ButtonSegment(
                    value: LanguagePreference.french,
                    label: Text(l10n.languageFrench),
                  ),
                ],
                selected: {settings.language},
                onSelectionChanged: (value) =>
                    controller.setLanguage(value.single),
              ),
            ),
            _Labeled(
              label: l10n.settingsColumns,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (var i = minGridColumns; i <= maxGridColumns; i++)
                    ButtonSegment(value: i, label: Text('$i')),
                ],
                selected: {settings.defaultColumns},
                onSelectionChanged: (value) {
                  unawaited(controller.setDefaultColumns(value.single));
                  ref.read(gridColumnsProvider.notifier).set(value.single);
                },
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsCorrectedDates),
              subtitle: Text(l10n.settingsCorrectedDatesHelp),
              value: settings.correctedDates,
              onChanged: (value) => controller.setCorrectedDates(value: value),
            ),
          ],
        ),
        _Section(
          title: l10n.settingsTrash,
          children: [
            _RetentionSlider(
              days: settings.trashRetentionDays,
              onChanged: controller.setTrashRetentionDays,
            ),
          ],
        ),
        _Section(
          title: l10n.settingsSharing,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsRemoveGps),
              subtitle: Text(l10n.settingsRemoveGpsHelp),
              value: settings.removeGpsOnShare,
              onChanged: (value) =>
                  controller.setRemoveGpsOnShare(value: value),
            ),
          ],
        ),
        const _AnalysisSection(),
        const _PermissionsSection(),
      ],
    );
  }
}

/// Re-running the analysis, with its progress.
class _AnalysisSection extends ConsumerWidget {
  const _AnalysisSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final running = ref.watch(duplicateScanProvider.select((s) => s.running));
    final syncing = ref.watch(mediaIndexProvider.select((s) => s.syncing));
    final busy = running || syncing;
    return _Section(
      title: l10n.settingsAnalysis,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.settingsReanalyze),
          subtitle: Text(l10n.settingsReanalyzeHelp),
          trailing: busy
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          onTap: busy
              ? null
              : () {
                  final messenger = ScaffoldMessenger.of(context);
                  unawaited(
                    ref.read(duplicateScanProvider.notifier).reanalyze(),
                  );
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.settingsReanalyzeStarted)),
                  );
                },
        ),
      ],
    );
  }
}

/// Card with a title and settings rows.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A label above a full-width control.
class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: child),
        ],
      ),
    );
  }
}

/// Trash retention slider (1–90 days); saved when the finger is lifted.
class _RetentionSlider extends StatefulWidget {
  const _RetentionSlider({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  State<_RetentionSlider> createState() => _RetentionSliderState();
}

class _RetentionSliderState extends State<_RetentionSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final days = (_dragging ?? widget.days.toDouble()).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.settingsRetention,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(l10n.retentionDays(days), style: theme.textTheme.titleSmall),
          ],
        ),
        SizedBox(
          height: 48,
          child: Slider(
            value: days.toDouble(),
            min: AppSettings.minRetentionDays.toDouble(),
            max: AppSettings.maxRetentionDays.toDouble(),
            divisions:
                AppSettings.maxRetentionDays - AppSettings.minRetentionDays,
            label: l10n.retentionDays(days),
            onChanged: (value) => setState(() => _dragging = value),
            onChangeEnd: (value) {
              widget.onChanged(value.round());
              setState(() => _dragging = null);
            },
          ),
        ),
        Text(
          l10n.settingsRetentionHelp,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Status of each permission, with a button to change it.
class _PermissionsSection extends ConsumerWidget {
  const _PermissionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(permissionStatusProvider).value;
    final permissions = ref.read(permissionServiceProvider);
    final bridge = ref.read(platformBridgeProvider);

    String yesNo({required bool granted}) =>
        granted ? l10n.permissionGranted : l10n.permissionDenied;

    Future<void> refreshAfter(Future<void> action) async {
      await action;
      ref
        ..invalidate(permissionStatusProvider)
        ..invalidate(mediaAccessProvider);
    }

    return _Section(
      title: l10n.settingsPermissions,
      children: [
        _PermissionRow(
          label: l10n.permissionMedia,
          status: switch (status?.media) {
            MediaAccess.granted => l10n.permissionGranted,
            MediaAccess.limited => l10n.permissionLimited,
            MediaAccess.denied => l10n.permissionDenied,
            null => '',
          },
          onChange: () => refreshAfter(
            status?.media == MediaAccess.denied
                ? permissions.requestMediaAccess().then((_) {})
                : permissions.openAppSettings(),
          ),
        ),
        _PermissionRow(
          label: l10n.permissionLocation,
          status: status == null ? '' : yesNo(granted: status.location),
          onChange: () => refreshAfter(
            status?.location ?? false
                ? permissions.openAppSettings()
                : permissions.requestLocationAccess().then((_) {}),
          ),
        ),
        _PermissionRow(
          label: l10n.permissionManage,
          help: l10n.permissionManageHelp,
          status: status == null ? '' : yesNo(granted: status.mediaManagement),
          onChange: () => refreshAfter(bridge.openMediaManagementSettings()),
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.label,
    required this.status,
    required this.onChange,
    this.help,
  });

  final String label;
  final String status;
  final String? help;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge),
                Text(
                  status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (help != null)
                  Text(
                    help!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: Text(l10n.permissionChange)),
        ],
      ),
    );
  }
}
