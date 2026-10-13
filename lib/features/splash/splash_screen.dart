import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/motion.dart';
import '../../core/permission_service.dart';
import '../../data/repository/music_repository.dart';
import '../../main.dart';
import '../permission/permission_screen.dart';

/// Premium animated splash screen for OffBeat.
///
/// Features a smooth fade + scale entrance of the OffBeat brand lockup,
/// an ambient glow on high-end hardware, and seamless transition into
/// either the main app shell (if permission granted) or PermissionScreen,
/// triggering the library scan exactly once after permission is confirmed.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  Timer? _navTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _scaleAnim = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (Motion.of(context).disableAnimations) {
          _controller.value = 1.0;
          _proceedNext();
          return;
        }
      }
    });

    // Seamless auto-advance after 1.4s
    _navTimer = Timer(const Duration(milliseconds: 1400), _proceedNext);
  }

  Future<void> _proceedNext() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    final isGranted = await PermissionService.isStorageGranted();
    if (!mounted) return;

    if (isGranted) {
      // Storage permission granted -> trigger scan exactly once (single-flight)
      ref.read(cachedScanProvider.future).ignore();

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainShellScaffold(),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
        ),
      );
    } else {
      // Permission not granted -> display PermissionScreen and trigger scan upon grant
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              PermissionScreen(
            onPermissionGranted: () {
              ref.read(cachedScanProvider.future).ignore();
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (_, _, _) => const MainShellScaffold(),
                  transitionDuration: const Duration(milliseconds: 300),
                  transitionsBuilder: (_, anim, _, child) =>
                      FadeTransition(opacity: anim, child: child),
                ),
              );
            },
          ),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLowEnd = Motion.isLowEnd;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _proceedNext, // Instant tap-to-skip
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnim.value,
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ambient glow behind emblem
                    if (!isLowEnd)
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.08),
                              blurRadius: 48,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),

                    // Official OffBeat logo
                    Image.asset(
                      'assets/images/logo.png',
                      width: 240,
                      height: 240,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
