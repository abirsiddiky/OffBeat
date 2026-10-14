import 'dart:io';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/motion.dart';
import 'core/permission_service.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'data/artwork/artwork_service.dart';
import 'data/db/app_database.dart';
import 'data/models/album_model.dart';
import 'data/repository/music_repository.dart';
import 'data/scanner/music_scanner.dart';
import 'features/album_detail/album_detail_screen.dart';
import 'features/home/home_screen.dart';
import 'features/hotlist/hotlist_screen.dart';
import 'features/library/library_screen.dart';
import 'features/now_playing/now_playing_screen.dart';
import 'features/permission/permission_screen.dart';
import 'features/search/search_screen.dart';
import 'playback/audio_controller.dart';
import 'playback/audio_handler.dart';
import 'shared/widgets/app_dock.dart';
import 'shared/widgets/nav_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Rule 4: Keep in-memory image cache bounded to avoid GC spikes on low-end hardware
  PaintingBinding.instance.imageCache.maximumSize = 150;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 60 * 1024 * 1024;

  // Rule 10: Debug-only FPS/jank logger for frames over 16 ms (compiled out in release)
  if (kDebugMode) {
    WidgetsBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
      for (final timing in timings) {
        final totalMs = timing.totalSpan.inMicroseconds / 1000.0;
        if (totalMs > 16.0) {
          final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
          final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;
          debugPrint(
            '[JANK] Frame > 16ms: ${totalMs.toStringAsFixed(1)}ms '
            '(Build: ${buildMs.toStringAsFixed(1)}ms, Raster: ${rasterMs.toStringAsFixed(1)}ms)',
          );
        }
      }
    });
  }

  // Section 1: Low-end device detection at startup (Android only)
  await Motion.detectLowEndDevice();

  int sdkInt = 0;
  if (Platform.isAndroid) {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      sdkInt = androidInfo.version.sdkInt;
    } catch (e) {
      debugPrint('[OffBeat] Android SDK detection error: $e');
    }
  }

  // Persistent shared preferences
  final prefs = await SharedPreferences.getInstance();

  // Eagerly initialize artwork disk cache directory for zero-latency checks
  await ArtworkService.init();

  // Database, scanner & repository
  final database = AppDatabase();
  final scanner = MusicScanner();
  final repository = MusicRepository(db: database, scanner: scanner);

  // Background AudioService initialization
  final audioHandler = await AudioService.init(
    builder: () => OffBeatAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.offbeat.offbeat.audio',
      androidNotificationChannelName: 'OffBeat',
      androidNotificationChannelDescription: 'OffBeat music playback controls',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      androidNotificationIcon: 'drawable/ic_stat_offbeat',
      notificationColor: Color(0xFF171C26),
      artDownscaleWidth: 256,
      artDownscaleHeight: 256,
    ),
  );

  // AudioController wiring
  final audioController = AudioController(audioHandler, repository);

  // Initial storage permission check on startup
  if (Platform.isAndroid) {
    try {
      await PermissionService.checkStorageStatus();
    } catch (e) {
      debugPrint('[OffBeat] Initial storage permission check error: $e');
    }
  }

  // Request notifications permission on Android 13+ (non-blocking)
  if (Platform.isAndroid && sdkInt >= 33) {
    PermissionService.requestNotificationPermissionIfNeeded().ignore();
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(database),
        musicScannerProvider.overrideWithValue(scanner),
        musicRepositoryProvider.overrideWithValue(repository),
        audioHandlerProvider.overrideWithValue(audioHandler),
        audioControllerProvider.overrideWithValue(audioController),
      ],
      child: const OffBeatApp(),
    ),
  );
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'rootNavigator',
);

/// Listenable bridge connecting permissionProvider changes to GoRouter refreshListenable
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen<PermissionStatus>(permissionProvider, (previous, next) {
      notifyListeners();
    });
  }
}

/// GoRouter provider created once, evaluating redirect using permissionProvider
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = RouterRefreshNotifier(ref);
  ref.onDispose(() => refreshNotifier.dispose());

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final status = ref.read(permissionProvider);
      final isGranted = status.isGranted || status.isLimited;
      final location = state.matchedLocation;

      String? target;
      if (!isGranted) {
        if (location != '/permission') {
          target = '/permission';
        }
      } else {
        if (location == '/permission') {
          target = '/';
        }
      }

      debugPrint(
        '[GoRouter redirect] location: $location -> target: ${target ?? 'none (allow)'} (status: $status)',
      );
      return target;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const MainShellScaffold(),
      ),
      GoRoute(
        path: '/permission',
        name: 'permission',
        builder: (context, state) => const PermissionScreen(),
      ),
    ],
  );
});

class OffBeatApp extends ConsumerStatefulWidget {
  const OffBeatApp({super.key});

  @override
  ConsumerState<OffBeatApp> createState() => _OffBeatAppState();
}

class _OffBeatAppState extends ConsumerState<OffBeatApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[AppLifecycle] App resumed -> refreshing permissionProvider');
      ref.read(permissionProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Section 4: Trigger first library scan exactly once on state transition denied -> granted
    ref.listen<PermissionStatus>(permissionProvider, (previous, next) {
      final wasGranted =
          previous != null && (previous.isGranted || previous.isLimited);
      final isGranted = next.isGranted || next.isLimited;

      if (!wasGranted && isGranted) {
        debugPrint('[Library] First scan triggered after permission granted');
        ref.invalidate(cachedScanProvider);
      }
    });

    final themeMode = ref.watch(themeModeProvider);
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    final currentTheme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      routerConfig: router,
      title: 'OffBeat',
      debugShowCheckedModeBanner: false,
      theme: currentTheme,
      builder: (context, child) {
        return AnimatedTheme(
          data: currentTheme,
          duration: Motion.normal, // Section 2g: 250 ms theme cross-fade
          curve: Motion.enter,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class MainShellScaffold extends StatefulWidget {
  const MainShellScaffold({super.key});

  @override
  State<MainShellScaffold> createState() => _MainShellScaffoldState();
}

class _MainShellScaffoldState extends State<MainShellScaffold> {
  NavTab _currentTab = NavTab.home;
  bool _isNowPlayingOpen = false;

  void _onTabSelected(NavTab tab) {
    if (_currentTab != tab) {
      setState(() => _currentTab = tab);
    }
  }

  void _openNowPlaying() {
    if (_isNowPlayingOpen) return;
    setState(() => _isNowPlayingOpen = true);
    Motion.isNowPlayingTransitioning.value = true;

    // Section 2a: Open on ROOT navigator with CustomTransitionPage / PageRouteBuilder
    // SlideTransition (Offset(0, 1) -> Offset.zero, enter curve, 350 ms; reverse 250 ms, exit curve)
    // Combined with light FadeTransition (0.85 -> 1.0). In low-end mode: plain fade only.
    final route = PageRouteBuilder(
      opaque: true, // Opaque theme background, zero overdraw
      transitionDuration: Motion.slow, // 350 ms
      reverseTransitionDuration: Motion.normal, // 250 ms
      pageBuilder: (context, animation, secondaryAnimation) {
        return NowPlayingScreen(
          onDismiss: () => Navigator.of(context).pop(),
          currentTab: _currentTab,
          onTabSelected: (tab) {
            _onTabSelected(tab);
          },
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (Motion.of(context).disableAnimations) {
          return child;
        }

        final isLowEnd = Motion.isLowEnd;
        if (isLowEnd) {
          final fade = Tween<double>(begin: 0.85, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: animation.status == AnimationStatus.reverse
                  ? Motion.exit
                  : Motion.enter,
            ),
          );
          return FadeTransition(opacity: fade, child: child);
        }

        final curvedAnim = CurvedAnimation(
          parent: animation,
          curve: Motion.enter,
          reverseCurve: Motion.exit,
        );

        final slide = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(curvedAnim);

        final fade = Tween<double>(begin: 0.85, end: 1.0).animate(curvedAnim);

        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: fade, child: child),
        );
      },
    );

    Navigator.of(context, rootNavigator: true).push(route).then((_) {
      if (mounted) {
        setState(() => _isNowPlayingOpen = false);
      }
      Motion.isNowPlayingTransitioning.value = false;
    });
  }

  void _navigateToAlbum(AlbumModel album) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(
          album: album,
          onBack: () => Navigator.of(context).pop(),
          onSearchTap: () {
            Navigator.of(context).pop();
            _onTabSelected(NavTab.search);
          },
        ),
      ),
    );
  }

  Widget _buildTabScreen(NavTab tab) {
    switch (tab) {
      case NavTab.home:
        return HomeScreen(
          onAlbumSelected: _navigateToAlbum,
          onOpenNowPlaying: _openNowPlaying,
        );
      case NavTab.search:
        return SearchScreen(onAlbumSelected: _navigateToAlbum);
      case NavTab.library:
        return LibraryScreen(onAlbumSelected: _navigateToAlbum);
      case NavTab.hotlist:
        return const HotlistScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Section 2e: Page content switches with cheap FadeTransition pair
          // (150 ms out / 200 ms in), no slide.
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                reverseDuration: const Duration(milliseconds: 150),
                switchInCurve: Motion.enter,
                switchOutCurve: Motion.exit,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(children: [...previousChildren, ?currentChild]);
                },
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: KeyedSubtree(
                  key: ValueKey(_currentTab),
                  child: _buildTabScreen(_currentTab),
                ),
              ),
            ),
          ),

          // Dock at bottom housing mini player and bottom nav bar
          // Section 2a: Mini player simply fades out while Now Playing is open
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppDock(
              currentTab: _currentTab,
              onTabSelected: _onTabSelected,
              onOpenNowPlaying: _openNowPlaying,
              showMiniPlayer: !_isNowPlayingOpen,
            ),
          ),
        ],
      ),
    );
  }
}
