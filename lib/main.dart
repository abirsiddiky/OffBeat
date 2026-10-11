import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'data/local/database.dart';
import 'data/providers/music_providers.dart';
import 'data/repositories/music_repository.dart';
import 'data/services/artwork_cache_service.dart';
import 'data/services/music_scanner.dart';
import 'data/services/permission_service.dart';
import 'playback/audio_handler.dart';
import 'playback/player_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Detect Android SDK version for diagnostics and permission logic
  int sdkInt = 0;
  if (Platform.isAndroid) {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      sdkInt = androidInfo.version.sdkInt;
    } catch (e) {
      debugPrint('[OffBeat] Failed to read Android SDK int: $e');
    }
  }

  debugPrint('[OffBeat][SDK: $sdkInt] Initializing application services...');

  // Initialize artwork cache service for local file:// URIs in notifications
  await ArtworkCacheService.instance.initialize();

  // Create persistent database and repository instances
  final database = OffBeatDatabase();
  final scanner = MusicScanner();
  final repository = MusicRepository(scanner: scanner, db: database);

  debugPrint(
    '[OffBeat][SDK: $sdkInt] Initializing AudioService with drawable/ic_stat_offbeat...',
  );

  // Initialize background AudioService with monochrome status bar icon
  final audioHandler = await AudioService.init(
    builder: () => OffBeatAudioHandler(
      repository: repository,
      sdkInt: sdkInt,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.offbeat.offbeat.audio',
      androidNotificationChannelName: 'OffBeat',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'drawable/ic_stat_offbeat',
      artDownscaleWidth: 256,
      artDownscaleHeight: 256,
    ),
  );

  debugPrint('[OffBeat][SDK: $sdkInt] AudioService.init completed successfully.');

  // Check POST_NOTIFICATIONS permission only on Android 13+ (non-blocking)
  if (Platform.isAndroid && sdkInt >= 33) {
    PermissionService().requestNotificationPermissionIfNeeded().ignore();
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        musicRepositoryProvider.overrideWithValue(repository),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const OffBeatApp(),
    ),
  );
}

class OffBeatApp extends ConsumerWidget {
  const OffBeatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'OffBeat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
