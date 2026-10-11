import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/data.dart';
import '../../playback/playback.dart';
import '../../shared/widgets/album_card.dart';
import '../../shared/widgets/track_tile.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<String> _tabs = const ['Songs', 'Albums', 'Artists', 'Playlists'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Library'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20, right: 20),
              child: Row(
                children: List.generate(_tabs.length, (index) {
                  final isSelected = _tabController.index == index;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == _tabs.length - 1 ? 0 : 8,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        _tabController.animateTo(index);
                        setState(() {});
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        decoration: ShapeDecoration(
                          color: isSelected
                              ? (isDark ? AppColors.white : AppColors.navy)
                              : Colors.transparent,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          _tabs[index],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected
                                ? (isDark
                                      ? const Color(0xFF171C26)
                                      : Colors.white)
                                : (isDark
                                      ? const Color(0xFFA4AAB7)
                                      : const Color(0xFF6C7689)),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SongsTab(),
          _AlbumsTab(),
          _ArtistsTab(),
          _PlaylistsTab(),
        ],
      ),
    );
  }
}

class _SongsTab extends ConsumerWidget {
  const _SongsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(allSongsProvider);

    return songsAsync.when(
      data: (songs) {
        if (songs.isEmpty) {
          return const Center(child: Text('No tracks found on device.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 12, bottom: 180),
          itemCount: songs.length,
          itemBuilder: (context, i) {
            final song = songs[i];
            return TrackTile(
              song: song,
              index: i,
              onTap: () {
                ref.read(playerControllerProvider.notifier).playSongs(songs, i);
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsProvider);
    final textScaler = MediaQuery.textScalerOf(context);

    return albumsAsync.when(
      data: (albums) {
        if (albums.isEmpty) {
          return const Center(child: Text('No albums found on device.'));
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            const crossAxisCount = 2;
            const crossAxisSpacing = 14.0;
            // 20 padding on left and right = 40 total
            final availableGridWidth = constraints.maxWidth - 40;
            final cardWidth =
                (availableGridWidth - crossAxisSpacing) / crossAxisCount;

            final titleH = textScaler.scale(18.0);
            final subtitleH = textScaler.scale(16.0);
            final extraHeight = 20.0 + 8.0 + titleH + 2.0 + subtitleH + 12.0;
            final mainAxisExtent = cardWidth + extraHeight;

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 180),
              itemCount: albums.length,
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
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return artistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) {
          return const Center(child: Text('No artists found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 180),
          itemCount: artists.length,
          itemBuilder: (context, i) {
            final artist = artists[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.rounded24,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.navyContainer
                        : AppColors.lightContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded),
                ),
                title: Text(artist.name, style: theme.textTheme.titleMedium),
                subtitle: Text(
                  '${artist.numberOfAlbums ?? 1} albums • ${artist.numberOfTracks ?? 0} tracks',
                  style: theme.textTheme.bodyMedium,
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  // Filter songs for this artist and play
                  final allSongs = ref.read(allSongsProvider).value ?? [];
                  final artistSongs = allSongs
                      .where(
                        (s) =>
                            s.artist.toLowerCase() == artist.name.toLowerCase(),
                      )
                      .toList();
                  if (artistSongs.isNotEmpty) {
                    ref
                        .read(playerControllerProvider.notifier)
                        .playSongs(artistSongs, 0);
                    context.push('/now-playing');
                  }
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 180),
      children: [
        // "+ New Playlist" action button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Playlist'),
            onPressed: () => _showCreatePlaylistDialog(context, ref),
          ),
        ),
        const SizedBox(height: 20),

        playlistsAsync.when(
          data: (playlists) {
            if (playlists.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        size: 56,
                        color: isDark ? AppColors.slate : AppColors.lightSlate,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No playlists yet',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create playlists to organize your favorite tracks.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: playlists.length,
              itemBuilder: (context, i) {
                final playlist = playlists[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.rounded24,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.navyContainer
                            : AppColors.lightContainer,
                        borderRadius: AppRadius.rounded16,
                      ),
                      child: const Icon(Icons.playlist_play_rounded),
                    ),
                    title: Text(
                      playlist.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Created ${playlist.createdAt.month}/${playlist.createdAt.day}/${playlist.createdAt.year}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      onPressed: () {
                        ref
                            .read(musicRepositoryProvider)
                            .deletePlaylist(playlist.id);
                      },
                    ),
                    onTap: () {
                      _openPlaylistModal(context, ref, playlist);
                    },
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ],
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New Playlist'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Playlist name...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  await ref.read(musicRepositoryProvider).createPlaylist(name);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _openPlaylistModal(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.r32),
        ),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final playlistSongsAsync = ref.watch(
              playlistSongsProvider(playlist.id),
            );

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.slate.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            playlist.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          playlistSongsAsync.maybeWhen(
                            data: (songs) => songs.isNotEmpty
                                ? ElevatedButton.icon(
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text('Play'),
                                    onPressed: () {
                                      ref
                                          .read(
                                            playerControllerProvider.notifier,
                                          )
                                          .playSongs(songs, 0);
                                      Navigator.pop(ctx);
                                      context.push('/now-playing');
                                    },
                                  )
                                : const SizedBox.shrink(),
                            orElse: () => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: playlistSongsAsync.when(
                          data: (songs) {
                            if (songs.isEmpty) {
                              return const Center(
                                child: Text('No songs in this playlist yet.'),
                              );
                            }
                            return ListView.builder(
                              controller: scrollController,
                              itemCount: songs.length,
                              itemBuilder: (context, i) {
                                final song = songs[i];
                                return TrackTile(
                                  song: song,
                                  index: i,
                                  onTap: () {
                                    ref
                                        .read(playerControllerProvider.notifier)
                                        .playSongs(songs, i);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, _) =>
                              const Center(child: Text('Error loading songs')),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
