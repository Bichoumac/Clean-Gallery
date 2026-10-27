import 'package:clean_gallery/core/router/home_shell.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/features/duplicates/duplicates_screen.dart';
import 'package:clean_gallery/features/library/albums_screen.dart';
import 'package:clean_gallery/features/library/media_timeline_view.dart';
import 'package:clean_gallery/features/onboarding/onboarding_controller.dart';
import 'package:clean_gallery/features/onboarding/onboarding_screen.dart';
import 'package:clean_gallery/features/settings/settings_screen.dart';
import 'package:clean_gallery/features/stats/stats_screen.dart';
import 'package:clean_gallery/features/trash/trash_screen.dart';
import 'package:clean_gallery/features/viewer/viewer_screen.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// Route paths. Use these constants, never inline strings.
abstract final class AppRoutes {
  /// First-launch onboarding.
  static const onboarding = '/onboarding';

  /// Camera tab: timeline of the camera's photos.
  static const camera = '/camera';

  /// Videos tab: timeline of videos.
  static const videos = '/videos';

  /// Albums tab: All media, Favorites and device folders.
  static const albums = '/albums';

  /// Stats tab: space that cleaning could free, and entry to cleanup tools.
  static const stats = '/stats';

  /// Settings tab.
  static const settings = '/settings';

  /// Full-screen viewer, above the tabs. Requires [ViewerArgs] as `extra`.
  static const viewer = '/viewer';

  /// Duplicates of one folder or tab, above the tabs. Requires the
  /// [MediaSelection] to look in as `extra`.
  static const duplicates = '/duplicates';
}

/// Album pages under the Albums tab: `/albums/<key>?name=<title>`.
abstract final class AlbumRoutes {
  /// Key of the "All media" virtual album.
  static const allKey = 'all';

  /// Key of the "Favorites" virtual album.
  static const favoritesKey = 'favorites';

  /// Location of the app trash, a page of its own under Albums.
  static const trash = '${AppRoutes.albums}/trash';

  /// Location of the album with [key] (a virtual key or a folder id).
  static String location(String key, String name) => Uri(
    path: '${AppRoutes.albums}/${Uri.encodeComponent(key)}',
    queryParameters: {'name': name},
  ).toString();

  /// Selection shown by the album with [key].
  static MediaSelection selectionFor(String key) => switch (key) {
    allKey => MediaSelection.all,
    favoritesKey => MediaSelection.favorites,
    _ => MediaSelection(albumId: key),
  };
}

/// What the viewer opens: a selection and the index of the first item.
@immutable
final class ViewerArgs {
  /// Creates viewer arguments.
  const ViewerArgs({required this.selection, required this.initialIndex});

  /// Items to swipe through.
  final MediaSelection selection;

  /// Index in [selection] of the item shown first.
  final int initialIndex;
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
    initialLocation: AppRoutes.camera,
    refreshListenable: refresh,
    redirect: (context, state) {
      final completed = ref.read(onboardingCompletedProvider);
      final onOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!completed && !onOnboarding) return AppRoutes.onboarding;
      if (completed && onOnboarding) return AppRoutes.camera;
      if (state.matchedLocation == AppRoutes.viewer &&
          state.extra is! ViewerArgs) {
        // A viewer location without arguments (e.g. after process death).
        return AppRoutes.camera;
      }
      if (state.matchedLocation == AppRoutes.duplicates &&
          state.extra is! MediaSelection) {
        return AppRoutes.camera;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.viewer,
        pageBuilder: (context, state) => CustomTransitionPage(
          child: ViewerScreen(args: state.extra! as ViewerArgs),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutes.duplicates,
        builder: (context, state) => DuplicatesScreen(
          scope: state.extra! as MediaSelection,
          kind: DuplicateKind.values
              .asNameMap()[state.uri.queryParameters['kind']],
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        // Order must match the destinations of HomeShell.
        branches: [
          _branch(
            AppRoutes.camera,
            (context, l10n) => MediaTimelineView(
              selection: MediaSelection.camera,
              title: l10n.navCamera,
              emptyTitle: l10n.libraryEmptyCamera,
            ),
          ),
          _branch(
            AppRoutes.videos,
            (context, l10n) => MediaTimelineView(
              selection: MediaSelection.videos,
              title: l10n.navVideos,
              emptyTitle: l10n.libraryEmptyVideos,
            ),
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.albums,
                builder: (context, state) => const AlbumsScreen(),
                routes: [
                  // Before ':key', which would otherwise match "trash".
                  GoRoute(
                    path: 'trash',
                    builder: (context, state) => const TrashScreen(),
                  ),
                  GoRoute(
                    path: ':key',
                    builder: (context, state) {
                      final l10n = AppLocalizations.of(context);
                      return MediaTimelineView(
                        selection: AlbumRoutes.selectionFor(
                          state.pathParameters['key']!,
                        ),
                        title: state.uri.queryParameters['name'] ?? '',
                        emptyTitle: l10n.libraryEmptyAlbum,
                        showBackButton: true,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.stats,
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// A tab branch with a single page built by [page].
StatefulShellBranch _branch(
  String path,
  Widget Function(BuildContext context, AppLocalizations l10n) page,
) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) =>
            page(context, AppLocalizations.of(context)),
      ),
    ],
  );
}
