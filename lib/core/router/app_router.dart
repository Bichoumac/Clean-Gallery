import 'package:clean_gallery/core/router/home_shell.dart';
import 'package:clean_gallery/core/router/tab_switcher.dart';
import 'package:clean_gallery/core/theme/app_motion.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/geo.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:clean_gallery/features/about/about_screen.dart';
import 'package:clean_gallery/features/cleanup/cleanup_list_screen.dart';
import 'package:clean_gallery/features/cleanup/cleanup_lists.dart';
import 'package:clean_gallery/features/duplicates/duplicates_screen.dart';
import 'package:clean_gallery/features/editor/editor_screen.dart';
import 'package:clean_gallery/features/library/albums_screen.dart';
import 'package:clean_gallery/features/library/media_timeline_view.dart';
import 'package:clean_gallery/features/map/map_area_screen.dart';
import 'package:clean_gallery/features/map/map_screen.dart';
import 'package:clean_gallery/features/memories/memories_screen.dart';
import 'package:clean_gallery/features/memories/memory_card.dart';
import 'package:clean_gallery/features/memories/rituals_screen.dart';
import 'package:clean_gallery/features/onboarding/onboarding_controller.dart';
import 'package:clean_gallery/features/onboarding/onboarding_screen.dart';
import 'package:clean_gallery/features/scan/scan_screen.dart';
import 'package:clean_gallery/features/search/search_controller.dart';
import 'package:clean_gallery/features/search/search_screen.dart';
import 'package:clean_gallery/features/settings/settings_screen.dart';
import 'package:clean_gallery/features/slideshow/slideshow_builder.dart';
import 'package:clean_gallery/features/slideshow/slideshow_screen.dart';
import 'package:clean_gallery/features/stats/stats_screen.dart';
import 'package:clean_gallery/features/swipe/swipe_screen.dart';
import 'package:clean_gallery/features/swipe/swipe_source.dart';
import 'package:clean_gallery/features/swipe/swipe_sources_screen.dart';
import 'package:clean_gallery/features/trash/trash_screen.dart';
import 'package:clean_gallery/features/user_albums/user_album_screen.dart';
import 'package:clean_gallery/features/viewer/viewer_screen.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
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

  /// A swipe session, above the tabs: `/swipe?source=<key>&name=<title>`.
  static const swipe = '/swipe';

  /// The map of located items, above the tabs. Takes an optional `GeoPoint`
  /// to open on as `extra`.
  static const map = '/map';

  /// The items of one cluster of the map. Requires its `GeoArea` as
  /// `extra`.
  static const mapArea = '/map/area';

  /// The photo editor, above the tabs. Requires the photo (`MediaItem`) as
  /// `extra`.
  static const editor = '/editor';

  /// The document scanner, above the tabs. Requires the photo
  /// (`MediaItem`) as `extra`.
  static const scan = '/scan';

  /// Search: criteria and results, inside the timeline given as
  /// `SearchArgs`.
  static const search = '/search';

  /// The map, to pick the area a search is limited to; pops a `GeoArea`.
  static const mapPick = '/map/pick';

  /// The slideshow player, above the tabs. Requires [SlideshowArgs] as
  /// `extra`.
  static const slideshow = '/slideshow';

  /// The rituals, under Settings.
  static const rituals = '/settings/rituals';

  /// About Clean Gallery, under Settings.
  static const about = '/settings/about';
}

/// Album pages under the Albums tab: `/albums/<key>?name=<title>`.
abstract final class AlbumRoutes {
  /// Key of the "All media" virtual album.
  static const allKey = 'all';

  /// Key of the "Favorites" virtual album.
  static const favoritesKey = 'favorites';

  /// Location of the app trash, a page of its own under Albums.
  static const trash = '${AppRoutes.albums}/trash';

  /// Location of the *Slideshows* page.
  static const slideshows = '${AppRoutes.albums}/slideshows';

  /// Location of the *Memories* list.
  static const memories = '${AppRoutes.albums}/memories';

  /// Location of the user album with [id].
  static String userAlbum(int id) => '${AppRoutes.albums}/mine/$id';

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

/// Cleanup lists under the Stats tab.
abstract final class CleanupRoutes {
  /// Location of [list].
  static String location(CleanupList list) => switch (list) {
    CleanupList.screenshots => '${AppRoutes.stats}/screenshots',
    CleanupList.largeVideos => '${AppRoutes.stats}/large-videos',
    CleanupList.poorQuality => '${AppRoutes.stats}/blurry',
  };
}

/// Sort mode (swipe).
abstract final class SwipeRoutes {
  /// The list of sources, under the Stats tab.
  static const sources = '${AppRoutes.stats}/swipe';

  /// The session of [source], titled [title].
  static String location(SwipeSource source, String title) => Uri(
    path: AppRoutes.swipe,
    queryParameters: {'source': source.key, 'name': title},
  ).toString();
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

/// What the slideshow player plays, and with which options (the user's
/// defaults when `null`).
@immutable
final class SlideshowArgs {
  /// Creates slideshow arguments.
  const SlideshowArgs({required this.source, this.options});

  /// What to play.
  final SlideshowSource source;

  /// Options chosen just before, if any.
  final SlideshowOptions? options;
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
      if ((state.matchedLocation == AppRoutes.editor ||
              state.matchedLocation == AppRoutes.scan) &&
          state.extra is! MediaItem) {
        return AppRoutes.camera;
      }
      if (state.matchedLocation == AppRoutes.slideshow &&
          state.extra is! SlideshowArgs) {
        return AppRoutes.camera;
      }
      if (state.matchedLocation == AppRoutes.mapArea &&
          state.extra is! GeoArea) {
        return AppRoutes.map;
      }
      if (state.matchedLocation == AppRoutes.swipe &&
          SwipeSource.parse(state.uri.queryParameters['source'] ?? '') ==
              null) {
        return AppRoutes.stats;
      }
      return null;
    },
    routes: [
      _route(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.viewer,
        pageBuilder: (context, state) => CustomTransitionPage(
          // As long as the photo's flight from its thumbnail.
          transitionDuration: AppMotion.viewer,
          reverseTransitionDuration: AppMotion.viewer,
          child: ViewerScreen(args: state.extra! as ViewerArgs),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutes.slideshow,
        pageBuilder: (context, state) {
          final args = state.extra! as SlideshowArgs;
          return CustomTransitionPage(
            child: SlideshowScreen(source: args.source, options: args.options),
            transitionsBuilder: (context, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          );
        },
      ),
      _route(
        path: AppRoutes.duplicates,
        builder: (context, state) => DuplicatesScreen(
          scope: state.extra! as MediaSelection,
          kind: DuplicateKind.values
              .asNameMap()[state.uri.queryParameters['kind']],
        ),
      ),
      _route(
        path: AppRoutes.editor,
        builder: (context, state) =>
            EditorScreen(photo: state.extra! as MediaItem),
      ),
      _route(
        path: AppRoutes.scan,
        builder: (context, state) =>
            ScanScreen(photo: state.extra! as MediaItem),
      ),
      _route(
        path: AppRoutes.map,
        builder: (context, state) => MapScreen(
          center: state.extra is GeoPoint ? state.extra! as GeoPoint : null,
        ),
        routes: [
          _route(
            path: 'area',
            builder: (context, state) =>
                MapAreaScreen(area: state.extra! as GeoArea),
          ),
          _route(
            path: 'pick',
            builder: (context, state) => MapScreen(
              pickArea: true,
              area: state.extra is GeoArea ? state.extra! as GeoArea : null,
            ),
          ),
        ],
      ),
      _route(
        path: AppRoutes.search,
        builder: (context, state) => SearchScreen(
          args: state.extra is SearchArgs
              ? state.extra! as SearchArgs
              : SearchArgs(
                  scope: MediaSelection.all,
                  place: AppLocalizations.of(context).albumsAllMedia,
                ),
        ),
      ),
      _route(
        path: AppRoutes.swipe,
        builder: (context, state) => SwipeScreen(
          source: SwipeSource.parse(state.uri.queryParameters['source']!)!,
          title: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      StatefulShellRoute(
        pageBuilder: (context, state, navigationShell) => MaterialPage<void>(
          key: state.pageKey,
          child: HomeShell(navigationShell: navigationShell),
        ),
        navigatorContainerBuilder: _branchContainer,
        // Order must match the destinations of HomeShell.
        branches: [
          _branch(
            AppRoutes.camera,
            (context, l10n) => MediaTimelineView(
              selection: MediaSelection.camera,
              title: l10n.navCamera,
              emptyTitle: l10n.libraryEmptyCamera,
              showSearch: true,
              topContent: const MemoryCards(),
            ),
          ),
          _branch(
            AppRoutes.videos,
            (context, l10n) => MediaTimelineView(
              selection: MediaSelection.videos,
              title: l10n.navVideos,
              emptyTitle: l10n.libraryEmptyVideos,
              showSearch: true,
            ),
          ),
          StatefulShellBranch(
            routes: [
              _route(
                path: AppRoutes.albums,
                builder: (context, state) => const AlbumsScreen(),
                routes: [
                  // Before ':key', which would otherwise match "trash".
                  _route(
                    path: 'trash',
                    builder: (context, state) => const TrashScreen(),
                  ),
                  _route(
                    path: 'slideshows',
                    builder: (context, state) => const SlideshowsScreen(),
                  ),
                  _route(
                    path: 'memories',
                    builder: (context, state) => const MemoriesScreen(),
                  ),
                  _route(
                    path: 'mine/:id',
                    builder: (context, state) => UserAlbumScreen(
                      albumId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                  _route(
                    path: ':key',
                    builder: (context, state) {
                      final l10n = AppLocalizations.of(context);
                      final name = state.uri.queryParameters['name'] ?? '';
                      return MediaTimelineView(
                        selection: AlbumRoutes.selectionFor(
                          state.pathParameters['key']!,
                        ),
                        title: name,
                        emptyTitle: l10n.libraryEmptyAlbum,
                        showBackButton: true,
                        showSearch: true,
                        slideshowTitle: name,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              _route(
                path: AppRoutes.stats,
                builder: (context, state) => const StatsScreen(),
                routes: [
                  _route(
                    path: 'screenshots',
                    builder: (context, state) =>
                        const CleanupListScreen(list: CleanupList.screenshots),
                  ),
                  _route(
                    path: 'large-videos',
                    builder: (context, state) =>
                        const CleanupListScreen(list: CleanupList.largeVideos),
                  ),
                  _route(
                    path: 'swipe',
                    builder: (context, state) => const SwipeSourcesScreen(),
                  ),
                  _route(
                    path: 'blurry',
                    builder: (context, state) =>
                        const CleanupListScreen(list: CleanupList.poorQuality),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              _route(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  _route(
                    path: 'rituals',
                    builder: (context, state) => const RitualsScreen(),
                  ),
                  _route(
                    path: 'about',
                    builder: (context, state) => const AboutScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// A route shown in a [MaterialPage], so it opens and closes with the
/// app's page transition.
///
/// go_router picks the kind of page from the app around it, and gave pages
/// without any transition here (2026-11-08): routes say it themselves.
GoRoute _route({
  required String path,
  required GoRouterWidgetBuilder builder,
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  routes: routes,
  pageBuilder: (context, state) => MaterialPage<void>(
    key: state.pageKey,
    name: state.name ?? state.path,
    arguments: state.extra,
    restorationId: state.pageKey.value,
    child: builder(context, state),
  ),
);

/// A tab branch with a single page built by [page].
StatefulShellBranch _branch(
  String path,
  Widget Function(BuildContext context, AppLocalizations l10n) page,
) {
  return StatefulShellBranch(
    routes: [
      _route(
        path: path,
        builder: (context, state) =>
            page(context, AppLocalizations.of(context)),
      ),
    ],
  );
}

/// The tabs' navigators, sliding from one to the other ([TabSwitcher]).
Widget _branchContainer(
  BuildContext context,
  StatefulNavigationShell navigationShell,
  List<Widget> children,
) => TabSwitcher(index: navigationShell.currentIndex, children: children);
