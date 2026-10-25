import 'package:clean_gallery/core/router/home_shell.dart';
import 'package:clean_gallery/features/onboarding/onboarding_controller.dart';
import 'package:clean_gallery/features/onboarding/onboarding_screen.dart';
import 'package:clean_gallery/features/stats/stats_screen.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// Route paths. Use these constants, never inline strings.
abstract final class AppRoutes {
  /// First-launch onboarding.
  static const onboarding = '/onboarding';

  /// Photos tab: timeline of photos.
  static const photos = '/photos';

  /// Videos tab: timeline of videos.
  static const videos = '/videos';

  /// Albums tab: folders, plus the Favorites and Trash virtual albums.
  static const albums = '/albums';

  /// Stats tab: space that cleaning could free, and entry to cleanup tools.
  static const stats = '/stats';

  /// Settings tab.
  static const settings = '/settings';
}

/// The application router.
///
/// While onboarding is incomplete, every location redirects to
/// [AppRoutes.onboarding]. The router is created once and never rebuilt:
/// the redirect reads the state at navigation time, and `refresh` re-runs it
/// when onboarding completes.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refresh = ValueNotifier(ref.read(onboardingCompletedProvider));
  ref
    ..listen(onboardingCompletedProvider, (_, completed) {
      refresh.value = completed;
    })
    ..onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.photos,
    refreshListenable: refresh,
    redirect: (context, state) {
      final completed = ref.read(onboardingCompletedProvider);
      final onOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!completed && !onOnboarding) return AppRoutes.onboarding;
      if (completed && onOnboarding) return AppRoutes.photos;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        // Order must match the destinations of HomeShell.
        branches: [
          _tab(AppRoutes.photos, (l10n) => l10n.navPhotos),
          _tab(AppRoutes.videos, (l10n) => l10n.navVideos),
          _tab(AppRoutes.albums, (l10n) => l10n.navAlbums),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.stats,
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
          _tab(AppRoutes.settings, (l10n) => l10n.navSettings),
        ],
      ),
    ],
  );
}

/// Branch for a tab that is still a placeholder.
StatefulShellBranch _tab(
  String path,
  String Function(AppLocalizations l10n) title,
) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) =>
            PlaceholderTab(title: title(AppLocalizations.of(context))),
      ),
    ],
  );
}
