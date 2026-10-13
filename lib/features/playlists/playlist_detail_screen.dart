import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../data/models/playlist_model.dart';
import '../../data/repository/music_repository.dart';
import '../../playback/audio_controller.dart';
import '../../shared/widgets/song_row_tile.dart';
import 'playlist_dialogs.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final PlaylistModel playlist;
  final VoidCallback onBack;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.navy;
    final playBtnBg = isDark ? AppColors.white : AppColors.navy;
    final playBtnTextColor = isDark ? AppColors.navy : AppColors.white;

    final songsAsync = ref.watch(playlistSongsProvider(playlist.id));
    final audioController = ref.watch(audioControllerProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: Icon(Icons.chevron_left_rounded, size: 32, color: primaryTextColor),
                      splashRadius: 24,
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => PlaylistDialogs.showRenameDialog(context, ref, playlist),
                          icon: const Icon(Icons.edit_outlined, color: AppColors.slate),
                          splashRadius: 22,
                        ),
                        IconButton(
                          onPressed: () {
                            PlaylistDialogs.showDeleteDialog(context, ref, playlist);
                            onBack();
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.slate),
                          splashRadius: 22,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Header Info
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Playlist',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      playlist.name,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Play & Shuffle buttons
                    songsAsync.when(
                      data: (songs) {
                        return Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: songs.isEmpty
                                      ? null
                                      : () => audioController.playQueue(songs, initialIndex: 0),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w700)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: playBtnBg,
                                    foregroundColor: playBtnTextColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: songs.isEmpty
                                      ? null
                                      : () {
                                          audioController.playQueue(songs, initialIndex: 0);
                                          audioController.toggleShuffle();
                                        },
                                  icon: Icon(Icons.shuffle_rounded, color: primaryTextColor),
                                  label: Text('Shuffle', style: TextStyle(fontWeight: FontWeight.w700, color: primaryTextColor)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? AppColors.darkRaisedSurface : AppColors.lightRaisedSurface,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (error, stack) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // Song list
            songsAsync.when(
              data: (songs) {
                if (songs.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'No songs in this playlist.\nAdd tracks from the Library or Album views.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.slate),
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final song = songs[idx];
                        return SongRowTile(
                          song: song,
                          index: idx,
                          showThumbnail: true,
                          showHeart: true,
                          onTap: () => audioController.playQueue(songs, initialIndex: idx),
                        );
                      },
                      childCount: songs.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: Center(child: Text('Error: $err')),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.totalDockHeight + 20),
            ),
          ],
        ),
      ),
    );
  }
}
