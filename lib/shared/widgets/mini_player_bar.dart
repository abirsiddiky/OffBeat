import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/music_providers.dart';
import '../../playback/player_controller.dart';
import 'marquee_text.dart';
import 'offbeat_artwork.dart';

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingProvider);

    final hasSong = currentSong != null;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use specific theme extension tokens from Phase 1
    final musicTheme = theme.extension<MusicPlayerThemeExtension>();
    final bgColor = musicTheme?.miniPlayerBackground ??
        (isDark ? AppColors.navyElevated : AppColors.navy);
    final fgColor = musicTheme?.miniPlayerForeground ?? AppColors.white;

    final isFavAsync = currentSong != null
        ? ref.watch(isFavoriteSongProvider(currentSong.id))
        : const AsyncValue.data(false);
    final isFav = isFavAsync.value ?? false;

    return AnimatedSlide(
      offset: hasSong ? Offset.zero : const Offset(0, 1.5),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: hasSong ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: hasSong
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: GestureDetector(
                  onTap: () => context.push('/now-playing'),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: bgColor.withValues(alpha: 0.95),
                      borderRadius: AppRadius.rounded24,
                      border: Border.all(
                        color: isDark
                            ? const Color(0x26FFFFFF)
                            : const Color(0x33FFFFFF),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? Colors.black : AppColors.navy)
                              .withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: AppRadius.rounded24,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Hero(
                                tag: 'player-art-${currentSong.id}',
                                child: OffBeatArtwork(
                                  id: currentSong.id,
                                  size: 48,
                                  borderRadius: AppRadius.rounded16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MarqueeText(
                                      key: ValueKey('mini-title-${currentSong.id}'),
                                      text: currentSong.title,
                                      style: TextStyle(
                                        color: fgColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currentSong.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.lightSlate,
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                iconSize: 22,
                                color: isFav ? AppColors.white : AppColors.lightSlate,
                                icon: Icon(
                                  isFav
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                ),
                                onPressed: () {
                                  ref
                                      .read(musicRepositoryProvider)
                                      .toggleFavorite(currentSong.id);
                                },
                              ),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  iconSize: 24,
                                  color: AppColors.navy,
                                  icon: Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(playerControllerProvider.notifier)
                                        .togglePlayPause();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
