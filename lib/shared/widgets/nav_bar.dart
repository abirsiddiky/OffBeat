import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/motion.dart';
import 'pressable.dart';

enum NavTab { home, search, library, hotlist }

class BottomNavPanel extends StatelessWidget {
  static const double navH = 76.0;

  final NavTab currentTab;
  final ValueChanged<NavTab> onTabSelected;

  const BottomNavPanel({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isLowEnd = Motion.isLowEnd;

    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return RepaintBoundary(
      child: Container(
        height: navH + bottomInset,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
              blurRadius: isLowEnd ? 12 : 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: navH,
            child: Row(
              children: [
                _BottomNavItem(
                  tab: NavTab.home,
                  label: 'Home',
                  inactiveIcon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  isSelected: currentTab == NavTab.home,
                  onTap: () => onTabSelected(NavTab.home),
                ),
                _BottomNavItem(
                  tab: NavTab.search,
                  label: 'Search',
                  inactiveIcon: Icons.search_rounded,
                  activeIcon: Icons.search_rounded,
                  isSelected: currentTab == NavTab.search,
                  onTap: () => onTabSelected(NavTab.search),
                ),
                _BottomNavItem(
                  tab: NavTab.library,
                  label: 'Library',
                  inactiveIcon: Icons.library_music_outlined,
                  activeIcon: Icons.library_music_rounded,
                  isSelected: currentTab == NavTab.library,
                  onTap: () => onTabSelected(NavTab.library),
                ),
                _BottomNavItem(
                  tab: NavTab.hotlist,
                  label: 'Hotlist',
                  inactiveIcon: Icons.local_fire_department_outlined,
                  activeIcon: Icons.local_fire_department_rounded,
                  isSelected: currentTab == NavTab.hotlist,
                  onTap: () => onTabSelected(NavTab.hotlist),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final NavTab tab;
  final String label;
  final IconData inactiveIcon;
  final IconData activeIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.tab,
    required this.label,
    required this.inactiveIcon,
    required this.activeIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLowEnd = Motion.isLowEnd;
    final motion = Motion.of(context);
    final animDuration = motion.disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 200);

    // Badge styling: navy in light theme, lighter navy in dark theme
    final badgeColor = isDark ? const Color(0xFF262D3D) : AppColors.navy;
    final unselectedColor = isDark ? AppColors.lightSlate : AppColors.slate;
    final activeTextColor = isDark ? AppColors.white : AppColors.navy;

    // Soft glow in dark mode (blur <= 16, omitted on low-end devices)
    final badgeGlow = (isDark && !isLowEnd)
        ? [
            BoxShadow(
              color: const Color(0xFF262D3D).withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ]
        : null;

    return Expanded(
      child: Semantics(
        selected: isSelected,
        label: label,
        button: true,
        child: Pressable(
          pressedScale: 0.96,
          duration: const Duration(milliseconds: 80),
          onTap: onTap,
          child: SizedBox(
            height: BottomNavPanel.navH,
            width: double.infinity,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 44 x 40 fixed container with badge & icon centered
                  SizedBox(
                    width: 44,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 1. The badge: AnimatedOpacity + AnimatedScale around Container
                        AnimatedOpacity(
                          opacity: isSelected ? 1.0 : 0.0,
                          duration: animDuration,
                          curve: Curves.easeOutCubic,
                          child: AnimatedScale(
                            scale: isSelected ? 1.0 : 0.85,
                            duration: animDuration,
                            curve: Curves.easeOutCubic,
                            child: Container(
                              width: 44,
                              height: 40,
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: badgeGlow,
                              ),
                            ),
                          ),
                        ),

                        // 2. The icon centered on top of the badge
                        TweenAnimationBuilder<Color?>(
                          duration: animDuration,
                          curve: Curves.easeOutCubic,
                          tween: ColorTween(
                            end: isSelected ? AppColors.white : unselectedColor,
                          ),
                          builder: (context, color, _) {
                            return Icon(
                              isSelected ? activeIcon : inactiveIcon,
                              size: 24,
                              color: color,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Label: AnimatedDefaultTextStyle (200 ms)
                  AnimatedDefaultTextStyle(
                    duration: animDuration,
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? activeTextColor : unselectedColor,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

typedef AppNavBar = BottomNavPanel;
