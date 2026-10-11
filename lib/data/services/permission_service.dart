import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service responsible for checking and requesting audio media and notification permissions across platforms.
class PermissionService {
  const PermissionService();

  /// Check whether the audio access permission is currently granted.
  Future<bool> hasPermission() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return true;
    }

    if (Platform.isAndroid) {
      // Check audio first (Android 13+)
      final audio = await Permission.audio.status;
      if (audio.isGranted || audio.isLimited) return true;

      // Check storage (Android 12 and below)
      final storage = await Permission.storage.status;
      if (storage.isGranted || storage.isLimited) return true;

      return false;
    }

    if (Platform.isIOS) {
      final status = await Permission.mediaLibrary.status;
      return status.isGranted || status.isLimited;
    }

    return true;
  }

  /// Request media permission from the user. Returns true if granted.
  Future<bool> requestPermission() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return true;
    }

    bool granted = false;
    if (Platform.isAndroid) {
      // Try audio permission first (Android 13+)
      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted || audioStatus.isLimited) {
        granted = true;
      } else {
        // Fallback to storage permission for older Android versions
        final storageStatus = await Permission.storage.request();
        granted = storageStatus.isGranted || storageStatus.isLimited;
      }

      // Request POST_NOTIFICATIONS only on Android 13+ (API 33)
      await requestNotificationPermissionIfNeeded();
      return granted;
    }

    if (Platform.isIOS) {
      final status = await Permission.mediaLibrary.request();
      return status.isGranted || status.isLimited;
    }

    return true;
  }

  /// Request POST_NOTIFICATIONS only on Android 13+ (API 33).
  /// On lower versions (Android 10-12), does nothing and never blocks playback.
  Future<void> requestNotificationPermissionIfNeeded() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt >= 33) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      }
    } catch (e) {
      debugPrint('[PermissionService] Notification permission check error: $e');
    }
  }

  /// Check if permission is permanently denied (requiring navigation to app settings)
  Future<bool> isPermanentlyDenied() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;

    if (Platform.isAndroid) {
      final audio = await Permission.audio.isPermanentlyDenied;
      final storage = await Permission.storage.isPermanentlyDenied;
      return audio || storage;
    }

    return Permission.mediaLibrary.isPermanentlyDenied;
  }

  /// Open application settings so user can grant permissions manually
  Future<bool> openSettings() async {
    return openAppSettings();
  }
}
