import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/providers/music_providers.dart';
import '../../playback/player_controller.dart';
import 'offbeat_artwork.dart';
import 'waveform_seek_bar.dart';

class TrackTile extends ConsumerWidget {
  final Song song;
  final int? index;
  final VoidCallback onTap;
  final bool showArtwork;

  const TrackTile({
    super.key,
    required this.song,
    this.index,
    required this.onTap,
    this.showArtwork = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final isCurrent = currentSong?.id == song.id;

    final isFavAsync = ref.watch(isFavoriteSongProvider(song.id));
    final isFav = isFavAsync.value ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? (isDark
                ? AppColors.navyElevated.withValues(alpha: 0.85)
                : AppColors.lightCard.withValues(alpha: 0.85))
            : Colors.transparent,
        borderRadius: AppRadius.rounded24,
        border: isCurrent
            ? Border.all(
                color: isDark
                    ? AppColors.white.withValues(alpha: 0.15)
                    : AppColors.navy.withValues(alpha: 0.08),
                width: 1,
              )
            : null,
      ),
      child: ListTile(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.rounded24,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index != null)
              SizedBox(
                width: 24,
                child: isCurrent && isPlaying
                    ? Icon(
                        Icons.graphic_eq_rounded,
                        size: 20,
                        color: isDark ? AppColors.white : AppColors.navy,
                      )
                    : Text(
                        '${index! + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isCurrent
                              ? (isDark ? AppColors.white : AppColors.navy)
                              : AppColors.slate,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
            if (index != null && showArtwork) const SizedBox(width: 12),
            if (showArtwork)
              OffBeatArtwork(
                id: song.id,
                size: 46,
                borderRadius: AppRadius.rounded16,
              ),
          ],
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
            color: isCurrent
                ? (isDark ? AppColors.white : AppColors.navy)
                : null,
          ),
        ),
        subtitle: Text(
          '${song.artist} • ${formatDuration(song.duration)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: isDark ? AppColors.lightSlate : AppColors.slate,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav
                    ? (isDark ? AppColors.white : AppColors.navy)
                    : AppColors.slate,
              ),
              onPressed: () {
                ref.read(musicRepositoryProvider).toggleFavorite(song.id);
              },
            ),
            _TrackOverflowMenu(song: song),
          ],
        ),
      ),
    );
  }
}

class _TrackOverflowMenu extends ConsumerWidget {
  final Song song;

  const _TrackOverflowMenu({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.rounded24,
      ),
      onSelected: (value) async {
        final controller = ref.read(playerControllerProvider.notifier);
        final repo = ref.read(musicRepositoryProvider);

        switch (value) {
          case 'playNext':
            controller.playNext(song);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Playing next: ${song.title}'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
              ),
            );
            break;
          case 'addToQueue':
            controller.addToQueue(song);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added to queue: ${song.title}'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
              ),
            );
            break;
          case 'toggleHotlist':
            final added = await repo.toggleFavorite(song.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    added ? 'Added to Hotlist' : 'Removed from Hotlist',
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
            break;
          case 'addToPlaylist':
            _showAddToPlaylistDialog(context, ref, song);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'playNext',
          child: Row(
            children: [
              Icon(Icons.skip_next_rounded, size: 20),
              SizedBox(width: 12),
              Text('Play Next'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'addToQueue',
          child: Row(
            children: [
              Icon(Icons.queue_music_rounded, size: 20),
              SizedBox(width: 12),
              Text('Add to Queue'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'toggleHotlist',
          child: Row(
            children: [
              Icon(Icons.local_fire_department_rounded, size: 20),
              SizedBox(width: 12),
              Text('Toggle Hotlist'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'addToPlaylist',
          child: Row(
            children: [
              Icon(Icons.playlist_add_rounded, size: 20),
              SizedBox(width: 12),
              Text('Add to Playlist'),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddToPlaylistDialog(
    BuildContext context,
    WidgetRef ref,
    Song song,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r32)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final playlistsAsync = ref.watch(playlistsProvider);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add to Playlist',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    playlistsAsync.when(
                      data: (playlists) {
                        if (playlists.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('No playlists created yet.'),
                            ),
                          );
                        }
                        return Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: playlists.length,
                            itemBuilder: (context, i) {
                              final p = playlists[i];
                              return ListTile(
                                leading: const Icon(Icons.playlist_play_rounded),
                                title: Text(p.name),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: AppRadius.rounded16,
                                ),
                                onTap: () async {
                                  await ref
                                      .read(musicRepositoryProvider)
                                      .addSongToPlaylist(p.id, song.id);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added to ${p.name}'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (_, _) => const Text('Failed to load playlists'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
