import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashLogger {
  CrashLogger._();

  static const String _logFileName = 'crash_log.txt';
  static File? _logFile;

  static Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/$_logFileName');
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }
    } catch (e) {
      debugPrint('[CrashLogger] Failed to init log file: $e');
    }

    // Capture Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      recordError(details.exception, details.stack);
    };

    // Capture asynchronous platform errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordError(error, stack);
      return true;
    };
  }

  static Future<void> recordError(Object error, StackTrace? stack) async {
    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp] ERROR: $error\nSTACK: ${stack ?? StackTrace.current}\n----------------------------------------\n';
    debugPrint(entry);

    try {
      if (_logFile != null) {
        await _logFile!.writeAsString(entry, mode: FileMode.append, flush: true);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$_logFileName');
        await file.writeAsString(entry, mode: FileMode.append, flush: true);
      }
    } catch (e) {
      debugPrint('[CrashLogger] Failed to write error to file: $e');
    }
  }

  static Future<String> readLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        final content = await _logFile!.readAsString();
        return content.isEmpty ? 'No crash logs recorded.' : content;
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_logFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        return content.isEmpty ? 'No crash logs recorded.' : content;
      }
    } catch (e) {
      return 'Error reading crash log: $e';
    }
    return 'No crash logs recorded.';
  }

  static Future<void> clearLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
      }
    } catch (e) {
      debugPrint('[CrashLogger] Failed to clear crash log: $e');
    }
  }
}
