import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget: theme and language from the settings, localization and
/// router.
class CleanGalleryApp extends ConsumerWidget {
  /// Creates the application root.
  const CleanGalleryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (settings.theme) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },
      // Null follows the system language.
      locale: switch (settings.language) {
        LanguagePreference.system => null,
        LanguagePreference.english => const Locale('en'),
        LanguagePreference.french => const Locale('fr'),
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
