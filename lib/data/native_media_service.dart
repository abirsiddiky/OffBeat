import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service interfacing with native Kotlin MethodChannel "offbeat/media".
class NativeMediaService {
  NativeMediaService._();

  static const MethodChannel _channel = MethodChannel('offbeat/media');

  /// LIGHT targeted media registration.
  ///
  /// Lists top level + 1 subfolder level of [dirs], checks audio extensions,
  /// filters lastModified > [sinceEpochMs], caps at [maxFiles],
  /// and invokes MediaScannerConnection.scanFile.
  static Future<int> scanRecent({
    required List<String> dirs,
    required int sinceEpochMs,
    int maxFiles = 200,
  }) async {
    try {
      final result = await _channel.invokeMethod<int>('scanRecent', {
        'dirs': dirs,
        'sinceEpochMs': sinceEpochMs,
        'maxFiles': maxFiles,
      });
      return result ?? 0;
    } catch (e) {
      debugPrint('[NativeMediaService] scanRecent invocation error: $e');
      return 0;
    }
  }

  /// Deletes audio files from device MediaStore.
  ///
  /// Returns:
  /// - `'deleted'`: successfully deleted by user / system
  /// - `'cancelled'`: user cancelled permission / confirmation dialog
  /// - `'error'`: deletion or security error occurred
  static Future<String> deleteAudio({
    required List<int> mediaStoreIds,
    String? filePath,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('deleteAudio', {
        'mediaStoreIds': mediaStoreIds,
        'filePath': filePath,
      });
      return result ?? 'error';
    } catch (e) {
      debugPrint('[NativeMediaService] deleteAudio invocation error: $e');
      return 'error';
    }
  }
}
