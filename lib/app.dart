import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget: theme (Material You when available), localization and router.
class CleanGalleryApp extends ConsumerWidget {
  /// Creates the application root.
  const CleanGalleryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: lightDynamic != null
              ? AppTheme.fromScheme(lightDynamic)
              : AppTheme.light(),
          darkTheme: darkDynamic != null
              ? AppTheme.fromScheme(darkDynamic)
              : AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        );
      },
    );
  }
}
