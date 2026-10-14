import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/motion.dart';
import '../../core/theme_provider.dart';
import '../../data/artwork/artwork_service.dart';
import '../../data/models/album_model.dart';
import '../../data/models/song_model.dart';
import '../../data/repository/music_repository.dart';
import '../../playback/audio_controller.dart';
import '../../data/scanner/rescan_controller.dart';
import '../../shared/widgets/album_grid_card.dart';
import '../../shared/widgets/fade_in_item.dart';
import '../../shared/widgets/pressable.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  final Function(AlbumModel album) onAlbumSelected;
  final VoidCallback onOpenNowPlaying;

  const HomeScreen({
    super.key,
    required this.onAlbumSelected,
    required this.onOpenNowPlaying,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.navy;
    final motion = Motion.of(context);
    final isRescanning = ref.watch(isRescanningProvider);

    final scanAsync = ref.watch(cachedScanProvider);
    final allAlbumsAsync = ref.watch(allAlbumsProvider);
    final recentlyPlayedAsync = ref.watch(recentlyPlayedProvider);
    final allSongsAsync = ref.watch(allSongsProvider);

    if (scanAsync.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: isDark ? AppColors.white : AppColors.navy,
              ),
              const SizedBox(height: 16),
              Text(
                'Scanning your music library...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          cacheExtent: 250.0,
          slivers: [
            // Top App Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenInset,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    // Logo + App Name
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.asset(
                        'assets/images/logo_icon.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'OffBeat',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const Spacer(),

                    // Rescan Icon Button
                    Pressable(
                      pressedScale: isRescanning ? 1.0 : 0.92,
                      duration: const Duration(milliseconds: 90),
                      onTap: isRescanning
                          ? null
                          : () {
                              ref.read(isRescanningProvider.notifier).triggerRescan(context);
                            },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: isRescanning
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.slate),
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, color: AppColors.slate, size: 24),
                      ),
                    ),

                    // Theme Toggle with 180° rotation + fade (250 ms)
                    Pressable(
                      pressedScale: 0.92,
                      duration: const Duration(milliseconds: 90),
                      onTap: () {
                        ref.read(themeModeProvider.notifier).toggleTheme(context);
                      },
                      onLongPress: () {
                        _showThemeSelectionSheet(context, ref);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkRaisedSurface : AppColors.lightRaisedSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: motion.normal,
                            transitionBuilder: (child, anim) {
                              final rotation = Tween<double>(begin: 0.5, end: 0.0).animate(
                                CurvedAnimation(parent: anim, curve: Motion.enter),
                              );
                              return RotationTransition(
                                turns: rotation,
                                child: FadeTransition(opacity: anim, child: child),
                              );
                            },
                            child: Icon(
                              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              key: ValueKey(isDark),
                              size: 20,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Settings Icon
                    Pressable(
                      pressedScale: 0.92,
                      duration: const Duration(milliseconds: 90),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.settings_outlined, color: AppColors.slate, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Section: Recently Played
            SliverToBoxAdapter(
              child: recentlyPlayedAsync.when(
                data: (recentSongs) {
                  final displaySongs = recentSongs.isNotEmpty
                      ? recentSongs
                      : (allSongsAsync.value?.take(6).toList() ?? []);

                  if (displaySongs.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenInset,
                          vertical: 8,
                        ),
                        child: Text(
                          'Recently Played',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 180,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          cacheExtent: 250.0,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
                          itemCount: displaySongs.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
                          itemBuilder: (context, idx) {
                            final song = displaySongs[idx];
                            return FadeInItem(
                              key: ValueKey(song.id),
                              itemId: song.id,
                              child: _RecentlyPlayedCard(
                                song: song,
                                onTap: () {
                                  ref.read(audioControllerProvider).playQueue(
                                        displaySongs,
                                        initialIndex: idx,
                                      );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),

            // Section: Albums Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.screenInset,
                  right: AppSpacing.screenInset,
                  top: 10,
                  bottom: 14,
                ),
                child: Text(
                  'Albums',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),

            // Section: Albums Grid
            allAlbumsAsync.when(
              data: (albums) {
                if (albums.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.screenInset),
                      child: Center(
                        child: Text('No albums found', style: TextStyle(color: AppColors.slate)),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 18,
                      mainAxisExtent: 224,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final album = albums[index];
                        return FadeInItem(
                          key: ValueKey(album.id),
                          itemId: album.id,
                          child: AlbumGridCard(
                            album: album,
                            onTap: () => onAlbumSelected(album),
                          ),
                        );
                      },
                      childCount: albums.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: Center(child: Text('Error loading albums: $err')),
              ),
            ),

            // Bottom safe inset for dock
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.totalDockHeight + 20),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeSelectionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final currentMode = ref.watch(themeModeProvider);

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkRaisedSurface : AppColors.lightRaisedSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose Appearance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.brightness_auto_rounded),
                title: const Text('System Default'),
                trailing: currentMode == ThemeMode.system ? const Icon(Icons.check_rounded) : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.light_mode_rounded),
                title: const Text('Light Clean'),
                trailing: currentMode == ThemeMode.light ? const Icon(Icons.check_rounded) : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.dark_mode_rounded),
                title: const Text('Dark Navy'),
                trailing: currentMode == ThemeMode.dark ? const Icon(Icons.check_rounded) : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentlyPlayedCard extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;

  const _RecentlyPlayedCard({
    required this.song,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.navy;

    return Pressable(
      pressedScale: 0.96,
      duration: const Duration(milliseconds: 90),
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark ? AppColors.darkRaisedSurface : AppColors.lightRaisedSurface,
              ),
              child: ArtworkService.getThumbWidget(
                id: int.tryParse(song.id) ?? (song.albumId ?? 0),
                songId: song.id,
                albumId: song.albumId,
                filePath: song.uri,
                size: 120,
                radius: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: AppColors.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
