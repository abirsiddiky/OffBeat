import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
export 'package:permission_handler/permission_handler.dart';

/// Centralized service managing Android storage and system permissions.
///
/// Ensures correct permission selection per Android API level:
/// - sdkInt >= 33: Permission.audio (READ_MEDIA_AUDIO)
/// - sdkInt <= 32: Permission.storage (READ_EXTERNAL_STORAGE)
class PermissionService {
  PermissionService._();

  static int? _cachedSdkInt;
  static Permission? _cachedPermission;

  /// Last known permission status
  static PermissionStatus? lastKnownStatus;

  /// Cached Android SDK version (defaults to 30 if not yet initialized)
  static int get sdkInt => _cachedSdkInt ?? 30;

  /// Reads AndroidDeviceInfo.version.sdkInt once and caches the result.
  static Future<int> getSdkInt() async {
    if (_cachedSdkInt != null) return _cachedSdkInt!;
    if (!Platform.isAndroid) {
      _cachedSdkInt = 0;
      return 0;
    }
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _cachedSdkInt = androidInfo.version.sdkInt;
      debugPrint('[PermissionService] Detected Android sdkInt: $_cachedSdkInt');
    } catch (e) {
      debugPrint('[PermissionService] Error reading Android sdkInt: $e');
      _cachedSdkInt = 30;
    }
    return _cachedSdkInt!;
  }

  /// Determines and caches the storage permission:
  /// - sdkInt >= 33 -> Permission.audio (READ_MEDIA_AUDIO)
  /// - sdkInt <= 32 -> Permission.storage (READ_EXTERNAL_STORAGE)
  static Future<Permission> getStoragePermission() async {
    if (_cachedPermission != null) return _cachedPermission!;
    final sdk = await getSdkInt();
    if (sdk >= 33) {
      _cachedPermission = Permission.audio;
      debugPrint('[PermissionService] sdkInt: $sdk >= 33 -> chosen permission: Permission.audio (READ_MEDIA_AUDIO)');
    } else {
      _cachedPermission = Permission.storage;
      debugPrint('[PermissionService] sdkInt: $sdk <= 32 -> chosen permission: Permission.storage (READ_EXTERNAL_STORAGE)');
    }
    return _cachedPermission!;
  }

  /// Checks the status of the chosen storage permission.
  static Future<PermissionStatus> checkStorageStatus() async {
    final permission = await getStoragePermission();
    final sdk = await getSdkInt();
    final status = await permission.status;
    lastKnownStatus = status;
    debugPrint('[PermissionService] checkStorageStatus (sdkInt: $sdk, chosen permission: $permission): status = $status');
    return status;
  }

  /// Returns true if the chosen storage permission is granted or limited.
  static Future<bool> isStorageGranted() async {
    final status = await checkStorageStatus();
    return status.isGranted || status.isLimited;
  }

  /// Requests the chosen storage permission, logging status before and after.
  /// ALWAYS re-reads the real status with .status afterwards and stores it; never trusts only the returned value.
  static Future<PermissionStatus> requestStoragePermission() async {
    final permission = await getStoragePermission();
    final sdk = await getSdkInt();
    final statusBefore = await permission.status;
    debugPrint('[PermissionService] requestStoragePermission (sdkInt: $sdk, chosen permission: $permission)');
    debugPrint('[PermissionService] Storage permission status BEFORE request: $statusBefore');

    await permission.request();
    // ALWAYS re-read real status afterwards with .status
    final statusAfter = await permission.status;
    lastKnownStatus = statusAfter;
    debugPrint('[PermissionService] Storage permission status AFTER request: $statusAfter');
    return statusAfter;
  }

  /// Opens application settings and logs the result.
  static Future<bool> openSettings() async {
    debugPrint('[PermissionService] Calling openAppSettings()...');
    final result = await openAppSettings();
    debugPrint('[PermissionService] openAppSettings result: $result');
    return result;
  }

  /// Requests POST_NOTIFICATIONS only on Android 13+ (API 33+).
  static Future<bool> requestNotificationPermissionIfNeeded() async {
    final sdk = await getSdkInt();
    if (sdk >= 33) {
      debugPrint('[PermissionService] Requesting POST_NOTIFICATIONS on Android 13+ (SDK $sdk)');
      try {
        final status = await Permission.notification.request();
        return status.isGranted;
      } catch (e) {
        debugPrint('[PermissionService] Notification permission request error: $e');
        return false;
      }
    } else {
      debugPrint('[PermissionService] Skipping notification permission request for SDK $sdk (< 33)');
      return true;
    }
  }

  /// Requests ignore battery optimization for playback reliability.
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('[PermissionService] Battery optimization request error: $e');
      return false;
    }
  }
}

/// Riverpod keepAlive single source of truth for audio/storage permission status.
class PermissionNotifier extends Notifier<PermissionStatus> {
  @override
  PermissionStatus build() {
    ref.keepAlive();
    if (PermissionService.lastKnownStatus == null) {
      Future.microtask(() => refresh());
    }
    return PermissionService.lastKnownStatus ?? PermissionStatus.denied;
  }

  /// Re-checks real status and updates state.
  Future<PermissionStatus> refresh() async {
    debugPrint('[PermissionNotifier] refresh() called');
    final status = await PermissionService.checkStorageStatus();
    debugPrint('[PermissionNotifier] refresh() -> real status: $status');
    state = status;
    return status;
  }

  /// Calls Permission.request(), ALWAYS re-reads the real status afterwards,
  /// stores it in state, and schedules retries after 300 ms and 800 ms.
  Future<PermissionStatus> request() async {
    debugPrint('[PermissionNotifier] request() called');
    final status = await PermissionService.requestStoragePermission();
    await PermissionService.requestNotificationPermissionIfNeeded();
    state = status;

    // Call refresh once after request returns, with short retries at 300 ms and 800 ms
    // because on some devices the status updates slightly after the dialog closes.
    Future.delayed(const Duration(milliseconds: 300), () {
      debugPrint('[PermissionNotifier] 300ms post-request retry refresh');
      refresh();
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      debugPrint('[PermissionNotifier] 800ms post-request retry refresh');
      refresh();
    });

    return status;
  }
}

final permissionProvider = NotifierProvider<PermissionNotifier, PermissionStatus>(() {
  return PermissionNotifier();
});
