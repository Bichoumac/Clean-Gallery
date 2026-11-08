import 'dart:async';

import 'package:clean_gallery/core/app_links.dart';
import 'package:clean_gallery/core/brand/petal_mark.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/compact_nav_bar.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'about_screen.g.dart';

/// The installed app's version name, e.g. `1.0.0`.
@riverpod
Future<String> appVersion(Ref ref) =>
    ref.watch(platformBridgeProvider).appVersion();

/// Opens [url] in the browser, or says in a snack bar that no app can.
Future<void> openAppLink(BuildContext context, WidgetRef ref, Uri url) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = AppLocalizations.of(context).aboutLinkFailed;
  final opened = await ref.read(platformBridgeProvider).openLink(url);
  if (!opened) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// About (Settings → About Clean Gallery): the app's promise and version,
/// links to the privacy policy, source code and issues, the license, the
/// licenses of the libraries and fonts, and the credits.
class AboutScreen extends ConsumerWidget {
  /// Creates the page.
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final version = ref.watch(appVersionProvider).value;

    Widget link(
      IconData icon,
      String title,
      String subtitle,
      Uri url, {
      Key? key,
    }) => ListTile(
      key: key,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new_rounded, size: 20),
      onTap: () => unawaited(openAppLink(context, ref, url)),
    );

    return Scaffold(
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
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.aboutTitle,
                          style: theme.textTheme.headlineMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  const EmptyMark(size: 88),
                  const SizedBox(height: 16),
                  Text(
                    'Clean Gallery',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (version != null && version.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.aboutVersion(version),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    l10n.aboutPromise,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.aboutOpenSource,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            sliver: SliverList.list(
              children: [
                link(
                  Icons.shield_outlined,
                  l10n.settingsPrivacyPolicy,
                  l10n.settingsPrivacyPolicyHelp,
                  AppLinks.privacyPolicy,
                ),
                link(
                  Icons.code_rounded,
                  l10n.aboutSourceCode,
                  l10n.aboutSourceCodeHelp,
                  AppLinks.source,
                ),
                link(
                  Icons.bug_report_outlined,
                  l10n.aboutReportProblem,
                  l10n.aboutReportProblemHelp,
                  AppLinks.issues,
                ),
                link(
                  Icons.gavel_rounded,
                  l10n.aboutLicense,
                  l10n.aboutLicenseHelp,
                  AppLinks.license,
                ),
                ListTile(
                  leading: const Icon(Icons.library_books_outlined),
                  title: Text(l10n.aboutLibraries),
                  subtitle: Text(l10n.aboutLibrariesHelp),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Clean Gallery',
                    applicationVersion: version,
                    applicationIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: EmptyMark(size: 56),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.aboutCredits,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                link(
                  Icons.map_outlined,
                  l10n.aboutCreditMap,
                  l10n.aboutCreditMapHelp,
                  AppLinks.openStreetMapCopyright,
                ),
                ListTile(
                  leading: const Icon(Icons.text_fields_rounded),
                  title: Text(l10n.aboutCreditFonts),
                  subtitle: Text(l10n.aboutCreditFontsHelp),
                ),
                for (final track in bundledTracks)
                  ListTile(
                    leading: const Icon(Icons.music_note_outlined),
                    title: Text(l10n.aboutCreditMusic(track.title)),
                    subtitle: Text(track.credit),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: CompactNavBar.contentInset(context) + 16),
          ),
        ],
      ),
    );
  }
}
