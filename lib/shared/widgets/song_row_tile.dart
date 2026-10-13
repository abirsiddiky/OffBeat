import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/motion.dart';
import '../../data/artwork/artwork_service.dart';
import '../../data/models/song_model.dart';
import '../../data/repository/music_repository.dart';
import '../../playback/audio_controller.dart';
import 'action_menu_sheet.dart';
import 'equalizer_icon.dart';
import 'pressable.dart';

class SongRowTile extends ConsumerWidget {
  static const double rowHeight = 64.0;

  final SongModel song;
  final int index;
  final VoidCallback onTap;
  final bool showThumbnail;
  final bool showHeart;

  const SongRowTile({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
    this.showThumbnail = false,
    this.showHeart = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingProvider);

    final isCurrentlyPlayingSong = currentSong?.id == song.id;

    final primaryTextColor = isDark ? AppColors.white : AppColors.navy;
    final highlightBg = isDark ? AppColors.darkRaisedSurface : AppColors.lightRaisedSurface;

    final favoritesAsync = ref.watch(favoritesProvider);
    final isFav = favoritesAsync.value?.any((s) => s.id == song.id) ?? false;

    return Pressable(
      pressedScale: 0.98,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Motion.enter,
        height: rowHeight,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isCurrentlyPlayingSong ? highlightBg : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            // Two digit index or Animated Equalizer (wrapped in RepaintBoundary)
            SizedBox(
              width: 28,
              child: isCurrentlyPlayingSong
                  ? Center(
                      child: EqualizerIcon(
                        isPlaying: isPlaying,
                        color: primaryTextColor,
                        size: 18,
                      ),
                    )
                  : Text(
                      Formatters.formatTrackNumber(index + 1),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate,
                      ),
                    ),
            ),

            // Optional 46 dp rounded thumbnail (Library view)
            if (showThumbnail) ...[
              const SizedBox(width: 8),
              ArtworkService.getThumbWidget(
                id: int.tryParse(song.id) ?? (song.albumId ?? 0),
                songId: song.id,
                albumId: song.albumId,
                filePath: song.uri,
                size: 46,
                radius: 12,
              ),
            ],

            const SizedBox(width: 14),

            // Title + "artist • m:ss"
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isCurrentlyPlayingSong ? FontWeight.w700 : FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${song.artist} • ${Formatters.formatDuration(song.duration)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ),
            ),

            // Optional Heart icon before three dots
            if (showHeart) ...[
              Pressable(
                pressedScale: 0.92,
                duration: const Duration(milliseconds: 90),
                onTap: () {
                  ref.read(musicRepositoryProvider).toggleFavorite(song.id);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 20,
                    color: isFav ? AppColors.red : AppColors.slate,
                  ),
                ),
              ),
            ],

            // Three dots action sheet trigger
            Pressable(
              pressedScale: 0.92,
              duration: const Duration(milliseconds: 90),
              onTap: () => ActionMenuSheet.show(context, song),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.slate,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
