import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../data/data.dart';
import '../../playback/playback.dart';
import '../../shared/widgets/album_card.dart';
import '../../shared/widgets/grant_permission_widget.dart';
import '../../shared/widgets/offbeat_artwork.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasPermissionAsync = ref.watch(musicPermissionProvider);
    final hasPermission = hasPermissionAsync.value ?? false;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/logo_badge.png',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Text('OffBeat'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Rescan Library',
            icon: const Icon(Icons.sync_rounded),
            onPressed: () {
              ref.read(allSongsProvider.notifier).rescan();
              ref.read(albumsProvider.notifier).rescan();
              ref.read(artistsProvider.notifier).rescan();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Scanning local library...'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          // Theme toggle button: single tap immediately toggles; long-press opens Preferences bottom sheet
          IconButton(
            tooltip: 'Toggle Theme (Long-press for options)',
            onPressed: () {
              final currentMode = ref.read(themeModeProvider);
              if (currentMode == ThemeMode.system) {
                // If mode is system, switch to the opposite of current effective brightness
                ref.read(themeModeProvider.notifier).setThemeMode(
                      isDark ? ThemeMode.light : ThemeMode.dark,
                    );
              } else {
                ref.read(themeModeProvider.notifier).setThemeMode(
                      currentMode == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark,
                    );
              }
            },
            onLongPress: () {
              _showSettingsModal(context, ref);
            },
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey<bool>(isDark),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !hasPermission
          ? GrantPermissionWidget(
              onGrantPermission: () =>
                  ref.read(musicPermissionProvider.notifier).request(),
              onOpenSettings: () =>
                  ref.read(permissionServiceProvider).openSettings(),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(allSongsProvider.notifier).rescan();
                await ref.read(albumsProvider.notifier).rescan();
                await ref.read(artistsProvider.notifier).rescan();
              },
              child: ListView(
                // Bottom padding accounts for mini player + floating nav bar + safe area (~180)
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 180),
                children: [
                  Text(
                    'Welcome Back',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pure sound, zero noise.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Horizontal "Recently Played" section
                  _RecentlyPlayedSection(),

                  const SizedBox(height: 32),

                  // Quick-access album grid
                  _AlbumsSection(),
                ],
              ),
            ),
    );
  }

  void _showSettingsModal(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.read(themeModeProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r32)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preferences',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.brightness_auto_rounded),
                  title: const Text('System Theme'),
                  trailing: currentTheme == ThemeMode.system
                      ? const Icon(Icons.check_rounded)
                      : null,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.rounded16,
                  ),
                  onTap: () {
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.system);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.dark_mode_rounded),
                  title: const Text('Dark Navy (#171C26)'),
                  trailing: currentTheme == ThemeMode.dark
                      ? const Icon(Icons.check_rounded)
                      : null,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.rounded16,
                  ),
                  onTap: () {
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.dark);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.light_mode_rounded),
                  title: const Text('Light Clean (#FFFFFF)'),
                  trailing: currentTheme == ThemeMode.light
                      ? const Icon(Icons.check_rounded)
                      : null,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.rounded16,
                  ),
                  onTap: () {
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.light);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecentlyPlayedSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final recentAsync = ref.watch(recentlyPlayedProvider);
    final textScaler = MediaQuery.textScalerOf(context);

    return recentAsync.when(
      data: (songs) {
        if (songs.isEmpty) return const SizedBox.shrink();

        // Calculate card height dynamically based on artwork (110) + padding (20) + text heights
        final titleH = textScaler.scale(18.0);
        final subtitleH = textScaler.scale(16.0);
        final listHeight = 110.0 + 20.0 + 8.0 + titleH + 2.0 + subtitleH + 12.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recently Played',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${songs.length} tracks',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: songs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final song = songs[i];
                  return GestureDetector(
                    onTap: () {
                      ref
                          .read(playerControllerProvider.notifier)
                          .playSongs(songs, i);
                    },
                    child: Container(
                      width: 130,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.navyElevated
                            : AppColors.lightCard,
                        borderRadius: AppRadius.rounded24,
                        border: Border.all(
                          color: isDark
                              ? const Color(0x1FFFFFFF)
                              : const Color(0x14171C26),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AspectRatio(
                            aspectRatio: 1.0,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return OffBeatArtwork(
                                  id: song.id,
                                  size: constraints.maxWidth,
                                  borderRadius: AppRadius.rounded16,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            child: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Flexible(
                            child: Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.lightSlate
                                    : AppColors.slate,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _AlbumsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final albumsAsync = ref.watch(albumsProvider);
    final textScaler = MediaQuery.textScalerOf(context);

    return albumsAsync.when(
      data: (albums) {
        if (albums.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No albums found on device.'),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick-Access Albums',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                const crossAxisCount = 2;
                const crossAxisSpacing = 14.0;
                final cardWidth =
                    (constraints.maxWidth - (crossAxisSpacing * (crossAxisCount - 1))) /
                        crossAxisCount;

                // Extra height: vertical padding (20) + spacing (8) + title line + subtitle line + safety margin
                final titleH = textScaler.scale(18.0);
                final subtitleH = textScaler.scale(16.0);
                final extraHeight = 20.0 + 8.0 + titleH + 2.0 + subtitleH + 12.0;
                final mainAxisExtent = cardWidth + extraHeight;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: albums.length > 8 ? 8 : albums.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: crossAxisSpacing,
                    mainAxisSpacing: 14,
                    mainAxisExtent: mainAxisExtent,
                  ),
                  itemBuilder: (context, i) {
                    final album = albums[i];
                    return AlbumCard(
                      album: album,
                      onTap: () => context.push('/album/${album.id}'),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Text('Error loading albums: $e'),
      ),
    );
  }
}
