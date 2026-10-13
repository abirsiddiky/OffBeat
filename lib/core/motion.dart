import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralized Global Motion System for OffBeat.
///
/// Provides unified duration tokens, curves, and device-tier adaptation
/// to guarantee steady 60 fps on low-end Android phones (2-3 GB RAM, weak GPU).
class Motion {
  Motion._();

  // Core duration tokens (no magic numbers elsewhere)
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);

  // Core curves
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve standard = Curves.easeInOutCubic;

  // Global flag for tracking whether Now Playing route is actively transitioning
  // Used by marquee and background workloads to pause expensive tickers.
  static final ValueNotifier<bool> isNowPlayingTransitioning = ValueNotifier<bool>(false);

  // Low-end device state (cached once at startup)
  static bool _isLowEnd = false;
  static bool get isLowEnd => _isLowEnd;

  /// Detects whether this Android device is considered low-end:
  /// sdkInt <= 29 OR isLowRamDevice (ActivityManager.isLowRamDevice via device_info_plus).
  static Future<bool> detectLowEndDevice() async {
    if (!Platform.isAndroid) {
      _isLowEnd = false;
      return false;
    }
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      final isLowRam = androidInfo.isLowRamDevice;
      _isLowEnd = sdkInt <= 29 || isLowRam;
      debugPrint('[Motion] Android SDK: $sdkInt, isLowRamDevice: $isLowRam -> lowEnd: $_isLowEnd');
    } catch (e) {
      debugPrint('[Motion] Device detection fallback: $e');
      _isLowEnd = false;
    }
    return _isLowEnd;
  }

  /// Returns contextual motion configuration adapted to device tier
  /// and Android "Remove animations" system accessibility setting.
  static MotionConfig of(BuildContext context) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return MotionConfig(
      disableAnimations: disable,
      isLowEnd: _isLowEnd,
    );
  }
}

/// Adaptive motion timings based on current device and accessibility settings.
class MotionConfig {
  final bool disableAnimations;
  final bool isLowEnd;

  const MotionConfig({
    required this.disableAnimations,
    required this.isLowEnd,
  });

  /// Scales or zeroes duration based on accessibility and low-end mode.
  Duration duration(Duration base) {
    if (disableAnimations) return Duration.zero;
    if (isLowEnd) {
      return Duration(milliseconds: (base.inMilliseconds * 0.6).round());
    }
    return base;
  }

  Duration get fast => duration(Motion.fast);
  Duration get normal => duration(Motion.normal);
  Duration get slow => duration(Motion.slow);

  Curve get enter => Motion.enter;
  Curve get exit => Motion.exit;
  Curve get standard => Motion.standard;
}

/// Riverpod provider exposing low-end device state.
final isLowEndDeviceProvider = Provider<bool>((ref) {
  return Motion.isLowEnd;
});
