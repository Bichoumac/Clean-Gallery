import 'package:clean_gallery/core/router/home_shell.dart';
import 'package:clean_gallery/features/onboarding/onboarding_controller.dart';
import 'package:clean_gallery/features/onboarding/onboarding_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// Route paths. Use these constants, never inline strings.
abstract final class AppRoutes {
  /// First-launch onboarding.
  static const onboarding = '/onboarding';

  /// Photos tab: timeline of all media.
  static const photos = '/photos';

  /// Folders tab: grid of albums.
  static const folders = '/folders';

  /// Clean tab: cleanup tools.
  static const clean = '/clean';
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
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.photos,
                builder: (context, state) => const PlaceholderTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.folders,
                builder: (context, state) => const PlaceholderTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.clean,
                builder: (context, state) => const PlaceholderTab(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
