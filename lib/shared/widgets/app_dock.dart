import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/motion.dart';
import '../../playback/audio_controller.dart';
import 'mini_player.dart';
import 'nav_bar.dart';

/// Provider for the total dock height (excluding safe-area inset)
final dockHeightProvider = Provider<double>((ref) {
  final currentSong = ref.watch(currentSongProvider);
  return AppDock.navH + (currentSong != null ? AppDock.miniH - AppDock.overlap : 0.0);
});

/// InheritedWidget exposing dock metrics to descendant screens
class DockScope extends InheritedWidget {
  final double totalHeight;
  final double navHeight;
  final bool hasMini;

  const DockScope({
    super.key,
    required this.totalHeight,
    required this.navHeight,
    required this.hasMini,
    required super.child,
  });

  static DockScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DockScope>();
  }

  static DockScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No DockScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(DockScope oldWidget) {
    return totalHeight != oldWidget.totalHeight ||
        navHeight != oldWidget.navHeight ||
        hasMini != oldWidget.hasMini;
  }
}

/// Dock widget housing MiniPlayerBar and BottomNavPanel
class AppDock extends ConsumerWidget {
  static const double navH = 76.0;
  static const double miniH = 100.0;
  static const double overlap = 28.0;

  final NavTab currentTab;
  final ValueChanged<NavTab> onTabSelected;
  final VoidCallback onOpenNowPlaying;
  final bool showMiniPlayer;

  const AppDock({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    required this.onOpenNowPlaying,
    this.showMiniPlayer = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final bottom = MediaQuery.of(context).padding.bottom;
    final hasMini = currentSong != null && showMiniPlayer;
    final motion = Motion.of(context);

    // Instant height change for list bottom padding (no animated height)
    final totalHeight = navH + bottom + (hasMini ? miniH - overlap : 0.0);

    return RepaintBoundary(
      child: DockScope(
        totalHeight: totalHeight,
        navHeight: navH + bottom,
        hasMini: hasMini,
        child: SizedBox(
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // (1) MINI PLAYER painted FIRST (behind nav panel)
              Positioned(
                left: 0,
                right: 0,
                bottom: navH + bottom - overlap,
                height: miniH,
                child: ClipRect(
                  child: OverflowBox(
                    minHeight: miniH,
                    maxHeight: miniH,
                    alignment: Alignment.topCenter,
                    child: AnimatedSlide(
                      duration: motion.normal,
                      curve: Motion.enter,
                      offset: hasMini ? Offset.zero : const Offset(0.0, 0.5),
                      child: AnimatedOpacity(
                        duration: motion.normal,
                        curve: Motion.enter,
                        opacity: hasMini ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: !hasMini,
                          child: MiniPlayerBar(
                            onTap: onOpenNowPlaying,
                            contentBottomPadding: overlap,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // (2) NAV PANEL painted SECOND (on top of mini player card)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: navH + bottom,
                child: BottomNavPanel(
                  currentTab: currentTab,
                  onTabSelected: onTabSelected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper shell scaffold embedding Dock at the bottom
class DockScaffold extends StatelessWidget {
  final Widget body;
  final Widget dock;

  const DockScaffold({
    super.key,
    required this.body,
    required this.dock,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          body,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: dock,
          ),
        ],
      ),
    );
  }
}

typedef Dock = AppDock;
