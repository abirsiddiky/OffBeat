import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/album_detail/album_detail_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/hotlist/hotlist_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/now_playing/now_playing_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../shared/widgets/scaffold_with_nav_bar.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    // Stateful shell route hosting the persistent floating pill navigation bar
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              name: 'search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              name: 'library',
              builder: (context, state) => const LibraryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hotlist',
              name: 'hotlist',
              builder: (context, state) => const HotlistScreen(),
            ),
          ],
        ),
      ],
    ),

    // Outside the shell routes (full-screen screens without the floating bottom nav bar)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/now-playing',
      name: 'nowPlaying',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const NowPlayingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/album/:id',
      name: 'albumDetail',
      builder: (context, state) {
        final albumId = state.pathParameters['id'] ?? 'unknown';
        return AlbumDetailScreen(albumId: albumId);
      },
    ),
  ],
);
