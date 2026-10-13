import 'permission_service.dart';

/// Legacy helper forwarding to [PermissionService] to ensure consistency.
class PermissionsHelper {
  PermissionsHelper._();

  /// Safely determine Android SDK API level
  static int get androidSdkInt => PermissionService.sdkInt;

  /// Check whether media/storage permission is granted
  static Future<bool> hasStoragePermission() => PermissionService.isStorageGranted();

  /// Request media/storage permission
  static Future<bool> requestStoragePermission() async {
    final status = await PermissionService.requestStoragePermission();
    return status.isGranted || status.isLimited;
  }

  /// Request POST_NOTIFICATIONS ONLY on Android 13+ (API 33+)
  static Future<bool> requestNotificationPermissionIfNeeded() =>
      PermissionService.requestNotificationPermissionIfNeeded();

  /// Request ignore battery optimization
  static Future<bool> requestIgnoreBatteryOptimizations() =>
      PermissionService.requestIgnoreBatteryOptimizations();
}
