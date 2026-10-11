import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'floating_bottom_nav_bar.dart';
import 'mini_player_bar.dart';

/// Wraps shell navigation screens with OffBeat's custom floating pill bottom nav bar
/// and docked MiniPlayerBar.
class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayerBar(),
          FloatingBottomNavBar(
            currentIndex: navigationShell.currentIndex,
            onTap: _onTap,
          ),
        ],
      ),
    );
  }
}
