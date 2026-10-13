import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../data/models/song_model.dart';
import '../../data/repository/music_repository.dart';
import '../../playback/audio_controller.dart';

class ActionMenuSheet extends ConsumerWidget {
  final SongModel song;

  const ActionMenuSheet({super.key, required this.song});

  static Future<void> show(BuildContext context, SongModel song) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ActionMenuSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkRaisedSurface : AppColors.lightRaisedSurface;
    final textColor = isDark ? AppColors.white : AppColors.navy;

    final favoritesAsync = ref.watch(favoritesProvider);
    final isFav = favoritesAsync.value?.any((s) => s.id == song.id) ?? false;
    final audioController = ref.watch(audioControllerProvider);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.slate.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Song title & artist header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${song.artist} • ${Formatters.formatDuration(song.duration)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.slate,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Menu Options
          _buildActionItem(
            icon: Icons.playlist_play_rounded,
            title: 'Play Next',
            textColor: textColor,
            onTap: () {
              Navigator.pop(context);
              audioController.playNext(song);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Playing "${song.title}" next')),
              );
            },
          ),
          _buildActionItem(
            icon: Icons.queue_music_rounded,
            title: 'Add to Queue',
            textColor: textColor,
            onTap: () {
              Navigator.pop(context);
              audioController.addToQueue(song);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added "${song.title}" to queue')),
              );
            },
          ),
          _buildActionItem(
            icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            title: isFav ? 'Remove from Favorites' : 'Add to Favorites',
            textColor: textColor,
            iconColor: isFav ? AppColors.red : null,
            onTap: () {
              Navigator.pop(context);
              ref.read(musicRepositoryProvider).toggleFavorite(song.id);
            },
          ),
          _buildActionItem(
            icon: Icons.playlist_add_rounded,
            title: 'Add to Playlist',
            textColor: textColor,
            onTap: () {
              Navigator.pop(context);
              _showAddToPlaylistDialog(context, ref, song);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required Color textColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor ?? textColor, size: 24),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, WidgetRef ref, SongModel song) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final playlistsAsync = ref.watch(playlistsProvider);
            return AlertDialog(
              title: const Text('Add to Playlist'),
              content: playlistsAsync.when(
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return const Text('No playlists created yet. Create one in Library tab.');
                  }
                  return SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (context, idx) {
                        final p = playlists[idx];
                        return ListTile(
                          title: Text(p.name),
                          subtitle: Text('${p.songCount} songs'),
                          onTap: () async {
                            await ref.read(musicRepositoryProvider).addSongToPlaylist(p.id, song.id);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Added to ${p.name}')),
                              );
                            }
                          },
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
