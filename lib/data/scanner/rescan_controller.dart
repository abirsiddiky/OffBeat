import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme_provider.dart';
import '../native_media_service.dart';
import '../repository/music_repository.dart';

/// Single-flight rescan notifier managing the Rescan button flow.
class RescanNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Executes the rescan button flow:
  /// 1. Sets isRescanning = true and shows progress on the button (disabled).
  /// 2. LIGHT targeted media registration via MethodChannel "offbeat/media".
  /// 3. scan(force: true) fresh querySongs via AudioQueryGate.
  /// 4. Diff new songs vs previous songs by id and update library state in place.
  /// 5. SnackBar feedback, debug logging on no additions, isRescanning = false in finally.
  Future<void> triggerRescan(BuildContext context) async {
    if (state) {
      debugPrint('[RescanController] Rescan already in flight; ignoring tap');
      return;
    }

    state = true;

    try {
      final SharedPreferences prefs;
      SharedPreferences? p;
      try {
        p = ref.read(sharedPreferencesProvider);
      } catch (_) {}
      prefs = p ?? await SharedPreferences.getInstance();

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastRescanMs = prefs.getInt('last_rescan_ms');
      final sinceEpochMs = lastRescanMs ??
          (nowMs - const Duration(days: 3).inMilliseconds);

      // Targeted search directories (only pass those that exist on device)
      const potentialDirs = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
      ];
      final existingDirs = potentialDirs
          .where((d) => Directory(d).existsSync())
          .toList();

      debugPrint(
        '[RescanController] Starting targeted scan. Existing dirs: $existingDirs, since: $sinceEpochMs',
      );

      // (b) Light targeted media registration via Kotlin MethodChannel
      final candidateCount = await NativeMediaService.scanRecent(
        dirs: existingDirs,
        sinceEpochMs: sinceEpochMs,
        maxFiles: 200,
      );

      debugPrint(
        '[RescanController] MediaScannerConnection completed. Scanned candidates: $candidateCount',
      );

      // (c) Fresh scan via AudioQueryGate
      final scanner = ref.read(musicScannerProvider);
      final newScanResult = await scanner.scan(force: true);

      // (d) Diff new song list against previous by id
      final previousScan = ref.read(cachedScanProvider).value;
      final previousSongs = previousScan?.songs ?? [];
      final previousIds = previousSongs.map((s) => s.id).toSet();

      final newlyAddedSongs = newScanResult.songs
          .where((s) => !previousIds.contains(s.id))
          .toList();
      final addedCount = newlyAddedSongs.length;

      // Update library state in place (re-derives albums & artists in Dart)
      ref.read(cachedScanProvider.notifier).updateState(newScanResult);

      // Save timestamp only after scan finishes successfully
      await prefs.setInt('last_rescan_ms', nowMs);

      // (e) Finish with SnackBar & debug log if nothing found
      if (context.mounted) {
        if (addedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$addedCount new songs added'),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          debugPrint(
            '[RescanController] No new songs found. Directories checked: $existingDirs, Candidate files registered: $candidateCount',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No new songs found'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e, st) {
      debugPrint('[RescanController] Couldn\'t rescan: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't rescan"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      state = false;
    }
  }
}

/// Provider exposing whether a rescan operation is currently active.
final isRescanningProvider = NotifierProvider<RescanNotifier, bool>(() {
  return RescanNotifier();
});
