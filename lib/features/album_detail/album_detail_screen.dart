import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/data.dart';
import '../../playback/playback.dart';
import '../../shared/widgets/offbeat_artwork.dart';
import '../../shared/widgets/track_tile.dart';

class AlbumDetailScreen extends ConsumerWidget {
  final String albumId;

  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final id = int.tryParse(albumId) ?? 0;
    final allAlbums = ref.watch(albumsProvider).value ?? [];
    final allSongs = ref.watch(allSongsProvider).value ?? [];

    final album = allAlbums.firstWhere(
      (a) => a.id == id,
      orElse: () => Album(
        id: id,
        title: 'Album #$albumId',
        artist: 'Various Artists',
        numberOfSongs: 0,
      ),
    );

    // Get all songs belonging to this album
    final albumSongs = allSongs.where((s) {
      if (s.albumId != null && s.albumId == id) return true;
      return s.album.trim().toLowerCase() == album.title.trim().toLowerCase();
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Add all to playlist',
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () {
              if (albumSongs.isNotEmpty) {
                _showAddAlbumToPlaylistDialog(context, ref, albumSongs);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 180),
        children: [
          // Album Art Header
          Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.rounded32,
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : AppColors.navy).withValues(
                      alpha: 0.25,
                    ),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: OffBeatArtwork(
                id: album.id,
                size: 220,
                borderRadius: AppRadius.rounded32,
                fallbackIcon: Icons.album_rounded,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Caption: "Album · N songs"
          Text(
            'Album • ${albumSongs.isNotEmpty ? albumSongs.length : album.numberOfSongs} songs',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? AppColors.lightSlate : AppColors.slate,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Large bold album title
          Text(
            album.title,
            style: theme.textTheme.displayMedium?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Artist name
          Text(
            album.artist,
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? AppColors.lightSlate : AppColors.slate,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Play (filled pill) + Shuffle (outlined pill) buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 26),
                  label: const Text('Play'),
                  style: ElevatedButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.rounded32,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    if (albumSongs.isNotEmpty) {
                      ref
                          .read(playerControllerProvider.notifier)
                          .playSongs(albumSongs, 0);
                      context.push('/now-playing');
                    }
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.shuffle_rounded, size: 22),
                  label: const Text('Shuffle'),
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.rounded32,
                    ),
                    side: BorderSide(
                      color: isDark ? AppColors.white : AppColors.navy,
                      width: 1.5,
                    ),
                    foregroundColor: isDark ? AppColors.white : AppColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  onPressed: () {
                    if (albumSongs.isNotEmpty) {
                      final shuffled = List<Song>.from(albumSongs)
                        ..shuffle(Random());
                      ref
                          .read(playerControllerProvider.notifier)
                          .playSongs(shuffled, 0);
                      context.push('/now-playing');
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Track list header
          Text(
            'Tracks',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),

          // Track list
          if (albumSongs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No tracks indexed for this album.')),
            )
          else
            ...List.generate(albumSongs.length, (i) {
              final song = albumSongs[i];
              return TrackTile(
                song: song,
                index: i,
                showArtwork: false,
                onTap: () {
                  ref
                      .read(playerControllerProvider.notifier)
                      .playSongs(albumSongs, i);
                },
              );
            }),
        ],
      ),
    );
  }

  void _showAddAlbumToPlaylistDialog(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.r32),
        ),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final playlistsAsync = ref.watch(playlistsProvider);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add Album to Playlist',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    playlistsAsync.when(
                      data: (playlists) {
                        if (playlists.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('No playlists created yet.'),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: playlists.length,
                          itemBuilder: (context, i) {
                            final p = playlists[i];
                            return ListTile(
                              leading: const Icon(Icons.playlist_play_rounded),
                              title: Text(p.name),
                              onTap: () async {
                                final repo = ref.read(musicRepositoryProvider);
                                for (final s in songs) {
                                  await repo.addSongToPlaylist(p.id, s.id);
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Added album to ${p.name}'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (_, _) => const Text('Error loading playlists'),
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
