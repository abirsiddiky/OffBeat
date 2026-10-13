import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../data/artwork/artwork_service.dart';
import '../../data/models/album_model.dart';
import '../../data/repository/music_repository.dart';
import '../../playback/audio_controller.dart';
import '../../shared/widgets/fade_in_item.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/song_row_tile.dart';

class AlbumDetailScreen extends ConsumerWidget {
  final AlbumModel album;
  final VoidCallback onBack;
  final VoidCallback onSearchTap;

  const AlbumDetailScreen({
    super.key,
    required this.album,
    required this.onBack,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.navy;
    final raisedBg = isDark ? AppColors.darkRaisedSurface : AppColors.lightRaisedSurface;
    final playBtnBg = isDark ? AppColors.white : AppColors.navy;
    final playBtnTextColor = isDark ? AppColors.navy : AppColors.white;

    final songs = ref.watch(albumSongsProvider(album.id));
    final audioController = ref.watch(audioControllerProvider);

    // Fallback if no songs found with exact albumId
    final allSongs = ref.watch(allSongsProvider).value ?? [];
    final effectiveSongs = songs.isNotEmpty
        ? songs
        : allSongs.where((s) => s.album.toLowerCase() == album.title.toLowerCase()).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          cacheExtent: 250.0,
          slivers: [
            // Top Navigation Bar (Back chevron left, Search icon right)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenInset,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Pressable(
                      pressedScale: 0.92,
                      duration: const Duration(milliseconds: 90),
                      onTap: onBack,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 32,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                    Text(
                      'Album',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    Pressable(
                      pressedScale: 0.92,
                      duration: const Duration(milliseconds: 90),
                      onTap: onSearchTap,
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.search_rounded,
                          size: 26,
                          color: AppColors.slate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Large Hero Artwork (square, rounded corners)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenInset,
                  vertical: 12,
                ),
                child: Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ArtworkService.getThumbWidget(
                      id: album.id,
                      albumId: album.id,
                      size: 220,
                      radius: 28,
                    ),
                  ),
                ),
              ),
            ),

            // Album Metadata
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
                child: Column(
                  children: [
                    Text(
                      album.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                        letterSpacing: -0.4,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      album.artist,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${album.songCount} tracks',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Two Equal Buttons: "Play" & "Shuffle"
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenInset,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Pressable(
                        pressedScale: 0.96,
                        duration: const Duration(milliseconds: 90),
                        onTap: () {
                          if (effectiveSongs.isNotEmpty) {
                            audioController.playQueue(effectiveSongs, initialIndex: 0);
                          }
                        },
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: playBtnBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_circle_outline_rounded, size: 24, color: playBtnTextColor),
                              const SizedBox(width: 8),
                              Text(
                                'Play',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: playBtnTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Pressable(
                        pressedScale: 0.96,
                        duration: const Duration(milliseconds: 90),
                        onTap: () {
                          if (effectiveSongs.isNotEmpty) {
                            audioController.playQueue(effectiveSongs, initialIndex: 0);
                            audioController.toggleShuffle();
                          }
                        },
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: raisedBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shuffle_rounded, size: 22, color: primaryTextColor),
                              const SizedBox(width: 8),
                              Text(
                                'Shuffle',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Track List with fixed extent (68.0) and FadeInItem
            if (effectiveSongs.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.screenInset),
                  child: Center(
                    child: Text('No tracks found in this album', style: TextStyle(color: AppColors.slate)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
                sliver: SliverFixedExtentList(
                  itemExtent: 68.0,
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = effectiveSongs[index];
                      return FadeInItem(
                        key: ValueKey(track.id),
                        itemId: track.id,
                        child: SongRowTile(
                          song: track,
                          index: index,
                          showThumbnail: false,
                          showHeart: false,
                          onTap: () {
                            audioController.playQueue(effectiveSongs, initialIndex: index);
                          },
                        ),
                      );
                    },
                    childCount: effectiveSongs.length,
                  ),
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
}
